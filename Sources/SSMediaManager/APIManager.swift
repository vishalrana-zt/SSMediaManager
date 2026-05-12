import Alamofire
import Foundation
import SwiftUI

public typealias UploadCompletion = (_ json: [String: Any]?, _ data: Data?, _ response: URLResponse?, _ error: Error?, _ indexPath: IndexPath?, _ index: Int?) -> Void

struct APIManager{
    
    var session:Session
    public static var shared = APIManager()
    
    private init(){
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 300
        configuration.timeoutIntervalForResource = 300
        configuration.waitsForConnectivity = true
        let rootQueue = DispatchQueue(label: "io.smartserv.session.rootQueue")
        let requestQueue = DispatchQueue(label: "io.smartserv.session.requestQueue")
        let serializationQueue = DispatchQueue(label: "io.smartserv.session.serializationQueue",attributes:.concurrent)
        
        session = Session(configuration: configuration, rootQueue:rootQueue,requestQueue:requestQueue,serializationQueue:serializationQueue,interceptor: RequestInterceptor())
    }

    func getUploadUrl(media:SSMedia, baseS3URL: String,indexPath: IndexPath?, index: Int?, completion:@escaping UploadCompletion){
        var params:[String:Any] = [:]
        if let companyId = UserDefaults.standard.string(forKey: "companyId") {
            params["companyId"] = companyId
        }
        params["contentType"] = media.mimeType
        params["fileName"] = media.name
        params["moduleName"] = media.moduleType.rawValue
        session.request(baseS3URL,parameters:params).responseData { responseData in
            processAPIResponse(responseData: responseData,indexPath: indexPath, index: index, completion: completion)
        }
    }
    
    func uploadMediaWith(uploadUrl:String, media:SSMedia,indexPath: IndexPath?, index: Int?, json: [String: Any]?,completion:@escaping UploadCompletion){
        if let path = media.filePath{
            let url = URL(fileURLWithPath: path)
            debugPrint("got filePath --->>\(path)")
            var headers = HTTPHeaders()
            headers["Content-Type"] = media.mimeType
            
            // Add EXIF metadata headers for image uploads
            if (media.mimeType ?? "").hasPrefix("image"), let exifMetadata = media.exifMetadata {
                let exifHeaders = EXIFMetadataHelper.convertToS3Headers(exifMetadata: exifMetadata)
                for (key, value) in exifHeaders {
                    headers[key] = value
                }
                debugPrint("Added EXIF metadata headers: \(exifHeaders.keys.joined(separator: ", "))")
            }
            
            // Add video metadata headers for video uploads
            if (media.mimeType ?? "").contains("video"), let videoMetadata = media.exifMetadata {
                let videoHeaders = EXIFMetadataHelper.convertVideoMetadataToS3Headers(videoMetadata: videoMetadata)
                for (key, value) in videoHeaders {
                    headers[key] = value
                }
                debugPrint("Added video metadata headers: \(videoHeaders.keys.joined(separator: ", "))")
            }
            
            session.upload(url, to: uploadUrl, method: .put, headers: headers).responseData  { data in
            if (data.response?.statusCode == 200){
                debugPrint("got upload success --->>\(data.response.debugDescription)")
                completion(json,nil,data.response,nil,indexPath,index)
                return
            }
            if let error = data.error as NSError? {
                debugPrint("got upload error --->>\(error.localizedDescription)")
                completion(nil, nil, nil, error,indexPath,index)
                return
            }
          }
        }
    }
    
    func processAPIResponse(responseData:AFDataResponse<Data>,indexPath: IndexPath?, index: Int?, completion:@escaping UploadCompletion){
        if let error = responseData.error as NSError? {
            completion(nil, nil, nil, error,indexPath,index)
            return
        }
        var json: [String:Any]?
        var error: Error?
        guard let data  = responseData.data else{
            completion(nil, nil,responseData.response, nil,indexPath,index)
            return
        }
        (json, error) = self.getJsonFromData(data: data)
        completion(json,data,responseData.response,error,indexPath,index)
    }
    
    func getJsonFromData(data: Data) -> ([String:Any]?, Error?) {
        do {
            let json = try JSONSerialization.jsonObject(with: data, options: .mutableContainers) as? [String : Any]
           return (json, nil)
        } catch {
            return (nil, error)
        }
    }
}

final class RequestInterceptor: Alamofire.RequestInterceptor{
      var retryLimit = 2
     var isRetrying = false
      let retryErrors = [NSURLErrorTimedOut,NSURLErrorCannotFindHost,NSURLErrorCannotParseResponse,NSURLErrorCannotConnectToHost,NSURLErrorCancelled]
    func adapt(_ urlRequest: URLRequest, for session: Session, completion: @escaping (Result<URLRequest, Error>) -> Void) {
        var urlRequest = urlRequest
//        urlRequest.setValue(TimeZone.current.identifier, forHTTPHeaderField: "timezonename")
//        urlRequest.setValue(String(TimeZone.current.timeZoneOffsetInMinutes()), forHTTPHeaderField: "timezone-offset")
        completion(.success(urlRequest))
    }
    
    func retry(_ request: Request, for session: Session, dueTo error: Error, completion: @escaping (RetryResult) -> Void) {
        if let urlError = error.asAFError?.underlyingError as? URLError{
            if shouldRetry(request, urlError) {
                debugPrint("retrying>>>")
                completion(.retry)
            } else {
                completion(.doNotRetry)
            }
        }else{
            completion(.doNotRetry)
        }
    }
    
    fileprivate func shouldRetry(_ request: Request, _ urlError: URLError) -> Bool {
        return request.retryCount < self.retryLimit && retryErrors.contains(urlError.errorCode)
    }

    
}
