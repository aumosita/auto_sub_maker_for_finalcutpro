import Foundation

/// Generates FCPXML subtitle files from transcription segments
final class FCPXMLGenerator {
    
    /// Generate FCPXML content from transcription segments (default Basic Title)
    func generate(
        segments: [TranscriptionSegment],
        style: SubtitleStyle,
        settings: ProjectSettings,
        template: FCPXMLTemplate? = nil,
        projectName: String = "Subtitles"
    ) -> String {
        let totalDuration = segments.last?.endTime ?? 0
        let fcpxmlDuration = settings.timeToFCPXML(totalDuration + 2) // Add 2s buffer
        
        // Determine effect to use
        let effectName: String
        let effectUID: String
        if let template = template {
            effectName = template.effectName
            effectUID = template.effectUID
        } else {
            effectName = "Basic Title"
            effectUID = ".../Titles.localized/Bumper:Opener.localized/Basic Title.localized/Basic Title.moti"
        }
        
        var xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE fcpxml>
        
        <fcpxml version="1.11">
            <resources>
                <format id="r1" name="\(settings.formatName)" frameDuration="\(settings.frameRate.frameDuration)" width="\(settings.width)" height="\(settings.height)"/>
                <effect id="r2" name="\(escapeXML(effectName))" uid="\(escapeXML(effectUID))"/>
            </resources>
            <library>
                <event name="\(escapeXML(projectName))">
                    <project name="\(escapeXML(projectName))">
                        <sequence format="r1" duration="\(fcpxmlDuration)" tcStart="0s" tcFormat="NDF">
                            <spine>
        
        """
        
        for (index, segment) in segments.enumerated() {
            let offset = settings.timeToFCPXML(segment.startTime)
            let duration = settings.timeToFCPXML(segment.duration)
            let styleId = "ts\(index + 1)"
            
            if let template = template {
                xml += generateTemplatedTitleElement(
                    segment: segment,
                    offset: offset,
                    duration: duration,
                    styleId: styleId,
                    template: template,
                    style: style
                )
            } else {
                xml += generateDefaultTitleElement(
                    segment: segment,
                    offset: offset,
                    duration: duration,
                    styleId: styleId,
                    style: style
                )
            }
        }
        
        xml += """
                            </spine>
                        </sequence>
                    </project>
                </event>
            </library>
        </fcpxml>
        """
        
        return xml
    }
    
    /// Generate title element using default Basic Title
    private func generateDefaultTitleElement(
        segment: TranscriptionSegment,
        offset: String,
        duration: String,
        styleId: String,
        style: SubtitleStyle
    ) -> String {
        let positionY = style.verticalPosition
        
        var fontFace = style.fontName
        if style.bold && style.italic {
            fontFace += " Bold Italic"
        } else if style.bold {
            fontFace += " Bold"
        } else if style.italic {
            fontFace += " Italic"
        }
        
        return """
                                <title ref="r2" offset="\(offset)" name="\(escapeXML(segment.text))" start="0s" duration="\(duration)">
                                    <param name="Position" key="9999/999166631/999166633/1/100/101" value="0 \(Int(positionY))"/>
                                    <text>
                                        <text-style ref="\(styleId)">\(escapeXML(segment.text))</text-style>
                                    </text>
                                    <text-style-def id="\(styleId)">
                                        <text-style font="\(escapeXML(style.fontName))" fontSize="\(Int(style.fontSize))" fontFace="\(escapeXML(fontFace))" fontColor="\(style.fcpxmlFontColor)" alignment="\(style.alignment.fcpxmlValue)" strokeColor="\(style.fcpxmlStrokeColor)" strokeWidth="\(Int(style.strokeWidth))"/>
                                    </text-style-def>
                                </title>
        
        """
    }
    
    /// Generate title element based on a parsed FCP template
    private func generateTemplatedTitleElement(
        segment: TranscriptionSegment,
        offset: String,
        duration: String,
        styleId: String,
        template: FCPXMLTemplate,
        style: SubtitleStyle
    ) -> String {
        var xml = "                            <title ref=\"r2\" offset=\"\(offset)\" name=\"\(escapeXML(segment.text))\" start=\"0s\" duration=\"\(duration)\">\n"
        
        // Reproduce template params (position, animation, etc.)
        for param in template.params {
            xml += "                                <param \(param.rawAttributes)/>\n"
        }
        
        // Text content
        xml += "                                <text>\n"
        xml += "                                    <text-style ref=\"\(styleId)\">\(escapeXML(segment.text))</text-style>\n"
        xml += "                                </text>\n"
        
        // Text style - use template style as base, override with user style settings
        xml += "                                <text-style-def id=\"\(styleId)\">\n"
        
        if let templateStyle = template.textStyleDef {
            // Merge template attributes with user overrides
            var attrs = templateStyle.allAttributes
            
            // Override with user style values
            attrs["font"] = style.fontName
            attrs["fontSize"] = "\(Int(style.fontSize))"
            attrs["fontColor"] = style.fcpxmlFontColor
            attrs["alignment"] = style.alignment.fcpxmlValue
            
            // Build font face
            var fontFace = style.fontName
            if style.bold && style.italic {
                fontFace += " Bold Italic"
            } else if style.bold {
                fontFace += " Bold"
            } else if style.italic {
                fontFace += " Italic"
            }
            attrs["fontFace"] = fontFace
            
            if style.strokeWidth > 0 {
                attrs["strokeColor"] = style.fcpxmlStrokeColor
                attrs["strokeWidth"] = "\(Int(style.strokeWidth))"
            }
            
            let attrString = attrs.map { "\($0.key)=\"\(escapeXML($0.value))\"" }.sorted().joined(separator: " ")
            xml += "                                    <text-style \(attrString)/>\n"
        } else {
            // Fallback to user style only
            var fontFace = style.fontName
            if style.bold && style.italic {
                fontFace += " Bold Italic"
            } else if style.bold {
                fontFace += " Bold"
            } else if style.italic {
                fontFace += " Italic"
            }
            xml += "                                    <text-style font=\"\(escapeXML(style.fontName))\" fontSize=\"\(Int(style.fontSize))\" fontFace=\"\(escapeXML(fontFace))\" fontColor=\"\(style.fcpxmlFontColor)\" alignment=\"\(style.alignment.fcpxmlValue)\" strokeColor=\"\(style.fcpxmlStrokeColor)\" strokeWidth=\"\(Int(style.strokeWidth))\"/>\n"
        }
        
        xml += "                                </text-style-def>\n"
        xml += "                            </title>\n"
        
        return xml
    }
    
    /// Save FCPXML content to file
    func save(content: String, to url: URL) throws {
        try content.write(to: url, atomically: true, encoding: .utf8)
    }
    
    /// Escape special XML characters
    private func escapeXML(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}
