import Foundation

/// Parsed FCP title template extracted from an FCPXML file
struct FCPXMLTemplate: Codable {
    /// Template name (from effect name attribute)
    var name: String
    /// Effect UID (unique identifier for the FCP title effect)
    var effectUID: String
    /// Effect name
    var effectName: String
    /// All <param> elements from the title as raw XML strings
    var params: [TemplateParam]
    /// Text style definition from the template
    var textStyleDef: TemplateTextStyle?
    /// The entire raw <title> element XML for reference
    var rawTitleXML: String
    /// Source file path
    var sourceFile: String
    
    struct TemplateParam: Codable {
        var name: String
        var key: String
        var value: String
        /// Full XML attribute string for this param
        var rawAttributes: String
    }
    
    struct TemplateTextStyle: Codable {
        var font: String?
        var fontSize: String?
        var fontFace: String?
        var fontColor: String?
        var alignment: String?
        var strokeColor: String?
        var strokeWidth: String?
        var bold: String?
        var italic: String?
        /// All attributes as key-value pairs for full fidelity reproduction
        var allAttributes: [String: String]
    }
}

/// Parses FCPXML files to extract title templates
final class FCPXMLTemplateParser {
    
    enum ParserError: LocalizedError {
        case fileNotFound
        case invalidXML(String)
        case noTitleFound
        case noEffectFound
        
        var errorDescription: String? {
            switch self {
            case .fileNotFound:
                return "FCPXML 파일을 찾을 수 없습니다."
            case .invalidXML(let detail):
                return "잘못된 XML 형식: \(detail)"
            case .noTitleFound:
                return "FCPXML에서 타이틀 요소를 찾을 수 없습니다."
            case .noEffectFound:
                return "FCPXML에서 이펙트 정의를 찾을 수 없습니다."
            }
        }
    }
    
    /// Parse an FCPXML file and extract the first title template
    func parse(fileURL: URL) throws -> FCPXMLTemplate {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw ParserError.fileNotFound
        }
        
        let data = try Data(contentsOf: fileURL)
        let xmlDoc = try XMLDocument(data: data)
        
        // Find effect elements in resources
        let effectNodes = try xmlDoc.nodes(forXPath: "//resources/effect")
        guard let effectNode = effectNodes.first as? XMLElement else {
            throw ParserError.noEffectFound
        }
        
        let effectUID = effectNode.attribute(forName: "uid")?.stringValue ?? ""
        let effectName = effectNode.attribute(forName: "name")?.stringValue ?? ""
        
        // Find the first title element
        let titleNodes = try xmlDoc.nodes(forXPath: "//title")
        guard let titleNode = titleNodes.first as? XMLElement else {
            throw ParserError.noTitleFound
        }
        
        // Extract params
        var params: [FCPXMLTemplate.TemplateParam] = []
        let paramNodes = try titleNode.nodes(forXPath: "param")
        for paramNode in paramNodes {
            guard let paramElement = paramNode as? XMLElement else { continue }
            let name = paramElement.attribute(forName: "name")?.stringValue ?? ""
            let key = paramElement.attribute(forName: "key")?.stringValue ?? ""
            let value = paramElement.attribute(forName: "value")?.stringValue ?? ""
            
            // Reconstruct raw attributes
            let rawAttrs = paramElement.attributes?.map { attr in
                "\(attr.name ?? "")=\"\(attr.stringValue ?? "")\""
            }.joined(separator: " ") ?? ""
            
            params.append(FCPXMLTemplate.TemplateParam(
                name: name,
                key: key,
                value: value,
                rawAttributes: rawAttrs
            ))
        }
        
        // Extract text-style-def
        var textStyle: FCPXMLTemplate.TemplateTextStyle?
        let textStyleNodes = try titleNode.nodes(forXPath: ".//text-style-def/text-style")
        if let styleNode = textStyleNodes.first as? XMLElement {
            var allAttrs: [String: String] = [:]
            for attr in styleNode.attributes ?? [] {
                allAttrs[attr.name ?? ""] = attr.stringValue ?? ""
            }
            
            textStyle = FCPXMLTemplate.TemplateTextStyle(
                font: allAttrs["font"],
                fontSize: allAttrs["fontSize"],
                fontFace: allAttrs["fontFace"],
                fontColor: allAttrs["fontColor"],
                alignment: allAttrs["alignment"],
                strokeColor: allAttrs["strokeColor"],
                strokeWidth: allAttrs["strokeWidth"],
                bold: allAttrs["bold"],
                italic: allAttrs["italic"],
                allAttributes: allAttrs
            )
        }
        
        let rawXML = titleNode.xmlString(options: .nodePrettyPrint)
        
        return FCPXMLTemplate(
            name: effectName,
            effectUID: effectUID,
            effectName: effectName,
            params: params,
            textStyleDef: textStyle,
            rawTitleXML: rawXML,
            sourceFile: fileURL.lastPathComponent
        )
    }
}
