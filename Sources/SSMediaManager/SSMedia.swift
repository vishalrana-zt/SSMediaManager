//
//  SSMedia.swift
//  SSMediaManager
//
//  Created by kuldeep on 30/05/22.
//

import Foundation
public struct SSMedia: Equatable{
    public var name:String
    public var id:String? = nil
    public var mimeType:String? = nil
    public var filePath:String? = nil
    public var data:Data? = nil
    public var serverUrl:String? = nil
    public var templateId:String? = nil
    public var moduleType: SSModuleType

    public init(name:String,id:String? = nil,mimeType:String?=nil,filePath:String? = nil,data:Data? = nil, templateId:String? = nil, serverUrl:String?=nil, moduleType:SSModuleType){
        self.name = name
        self.id = id
        self.mimeType = mimeType
        self.filePath = filePath
        self.data = data
        self.templateId = templateId
        self.serverUrl = serverUrl
        self.moduleType = moduleType
    }
    
}


public enum SSModuleType : String {
    case notes = "notes"
    case equipments = "equipments"
    case assets = "assets"
    case forms = "fpForms"
    case formTemplate = "formTemplate"
    case signature = "signature"
    case invoice = "invoice"
    case estimate = "estimate"
}
