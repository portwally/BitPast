//
//  ApplesoftTokenizer.swift
//  BitPast
//
//  Converts Applesoft BASIC source code to tokenized format
//

import Foundation

class ApplesoftTokenizer {

    // Applesoft BASIC tokens ($80-$EA)
    private static let tokens: [String: UInt8] = [
        "END": 0x80, "FOR": 0x81, "NEXT": 0x82, "DATA": 0x83,
        "INPUT": 0x84, "DEL": 0x85, "DIM": 0x86, "READ": 0x87,
        "GR": 0x88, "TEXT": 0x89, "PR#": 0x8A, "IN#": 0x8B,
        "CALL": 0x8C, "PLOT": 0x8D, "HLIN": 0x8E, "VLIN": 0x8F,
        "HGR2": 0x90, "HGR": 0x91, "HCOLOR=": 0x92, "HPLOT": 0x93,
        "DRAW": 0x94, "XDRAW": 0x95, "HTAB": 0x96, "HOME": 0x97,
        "ROT=": 0x98, "SCALE=": 0x99, "SHLOAD": 0x9A, "TRACE": 0x9B,
        "NOTRACE": 0x9C, "NORMAL": 0x9D, "INVERSE": 0x9E, "FLASH": 0x9F,
        "COLOR=": 0xA0, "POP": 0xA1, "VTAB": 0xA2, "HIMEM:": 0xA3,
        "LOMEM:": 0xA4, "ONERR": 0xA5, "RESUME": 0xA6, "RECALL": 0xA7,
        "STORE": 0xA8, "SPEED=": 0xA9, "LET": 0xAA, "GOTO": 0xAB,
        "RUN": 0xAC, "IF": 0xAD, "RESTORE": 0xAE, "\"&\"": 0xAF,
        "GOSUB": 0xB0, "RETURN": 0xB1, "REM": 0xB2, "STOP": 0xB3,
        "ON": 0xB4, "WAIT": 0xB5, "LOAD": 0xB6, "SAVE": 0xB7,
        "DEF": 0xB8, "POKE": 0xB9, "PRINT": 0xBA, "CONT": 0xBB,
        "LIST": 0xBC, "CLEAR": 0xBD, "GET": 0xBE, "NEW": 0xBF,
        "TAB(": 0xC0, "TO": 0xC1, "FN": 0xC2, "SPC(": 0xC3,
        "THEN": 0xC4, "AT": 0xC5, "NOT": 0xC6, "STEP": 0xC7,
        "+": 0xC8, "-": 0xC9, "*": 0xCA, "/": 0xCB,
        "^": 0xCC, "AND": 0xCD, "OR": 0xCE, ">": 0xCF,
        "=": 0xD0, "<": 0xD1, "SGN": 0xD2, "INT": 0xD3,
        "ABS": 0xD4, "USR": 0xD5, "FRE": 0xD6, "SCRN(": 0xD7,
        "PDL": 0xD8, "POS": 0xD9, "SQR": 0xDA, "RND": 0xDB,
        "LOG": 0xDC, "EXP": 0xDD, "COS": 0xDE, "SIN": 0xDF,
        "TAN": 0xE0, "ATN": 0xE1, "PEEK": 0xE2, "LEN": 0xE3,
        "STR$": 0xE4, "VAL": 0xE5, "ASC": 0xE6, "CHR$": 0xE7,
        "LEFT$": 0xE8, "RIGHT$": 0xE9, "MID$": 0xEA
    ]

    // Sorted tokens by length (longest first) for matching
    private static let sortedTokens: [(String, UInt8)] = {
        tokens.sorted { $0.key.count > $1.key.count }
    }()

    /// Tokenize an Applesoft BASIC program from source text
    /// - Parameter source: The BASIC source code as text
    /// - Returns: Tokenized binary data ready to be saved as a BAS file
    static func tokenize(_ source: String) -> Data {
        var result = Data()

        // Parse lines
        let lines = source.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        // Start address for Applesoft programs (typically $0801)
        var currentAddress: UInt16 = 0x0801

        for line in lines {
            guard let tokenizedLine = tokenizeLine(line, startAddress: currentAddress) else {
                continue
            }
            result.append(tokenizedLine)
            currentAddress += UInt16(tokenizedLine.count)
        }

        // Add end-of-program marker (two zero bytes for null link pointer)
        result.append(0x00)
        result.append(0x00)

        return result
    }

    /// Tokenize a single line of BASIC
    private static func tokenizeLine(_ line: String, startAddress: UInt16) -> Data? {
        // Parse line number
        var remaining = line
        var lineNumber: UInt16 = 0

        // Extract line number
        var numberStr = ""
        while let first = remaining.first, first.isNumber {
            numberStr.append(first)
            remaining.removeFirst()
        }

        guard let num = UInt16(numberStr) else {
            return nil
        }
        lineNumber = num

        // Skip whitespace after line number
        remaining = remaining.trimmingCharacters(in: .whitespaces)

        // Tokenize the rest of the line
        var tokenizedContent = Data()
        var inString = false
        var inREM = false
        var inDATA = false

        while !remaining.isEmpty {
            // Handle string literals
            if remaining.first == "\"" {
                inString.toggle()
                tokenizedContent.append(UInt8(ascii: "\""))
                remaining.removeFirst()
                continue
            }

            if inString {
                // Inside string - copy characters as plain ASCII (NO high bit)
                if let asciiValue = remaining.first?.asciiValue {
                    tokenizedContent.append(asciiValue)
                }
                remaining.removeFirst()
                continue
            }

            // After REM, copy rest of line as plain ASCII
            if inREM {
                for char in remaining {
                    if let ascii = char.asciiValue {
                        tokenizedContent.append(ascii)
                    }
                }
                break
            }

            // After DATA until colon, copy as plain ASCII
            if inDATA {
                if remaining.first == ":" {
                    inDATA = false
                    tokenizedContent.append(UInt8(ascii: ":"))
                    remaining.removeFirst()
                    continue
                }
                if let asciiValue = remaining.first?.asciiValue {
                    tokenizedContent.append(asciiValue)
                }
                remaining.removeFirst()
                continue
            }

            // Try to match a token
            var matched = false
            let upperRemaining = remaining.uppercased()

            for (keyword, token) in sortedTokens {
                if upperRemaining.hasPrefix(keyword) {
                    tokenizedContent.append(token)
                    remaining.removeFirst(keyword.count)
                    matched = true

                    if keyword == "REM" {
                        inREM = true
                    } else if keyword == "DATA" {
                        inDATA = true
                    }
                    break
                }
            }

            if !matched {
                // Not a token - copy character as plain ASCII (NO high bit)
                // Variable names, operators, etc. are all plain ASCII in Applesoft
                if let char = remaining.first {
                    if let asciiValue = char.asciiValue {
                        tokenizedContent.append(asciiValue)
                    }
                    remaining.removeFirst()
                }
            }
        }

        // Build the complete line:
        // 2 bytes: link to next line
        // 2 bytes: line number
        // n bytes: tokenized content
        // 1 byte: 0x00 (end of line)

        let lineLength = 4 + tokenizedContent.count + 1
        let nextLineAddress = startAddress + UInt16(lineLength)

        var lineData = Data()

        // Link pointer to next line
        lineData.append(UInt8(nextLineAddress & 0xFF))
        lineData.append(UInt8((nextLineAddress >> 8) & 0xFF))

        // Line number
        lineData.append(UInt8(lineNumber & 0xFF))
        lineData.append(UInt8((lineNumber >> 8) & 0xFF))

        // Tokenized content
        lineData.append(tokenizedContent)

        // End of line marker
        lineData.append(0x00)

        return lineData
    }

    /// Generate a SLIDESHOW program that displays HGR/DHGR images
    /// - Parameters:
    ///   - fileNames: List of image filenames on the disk (prefix with * for DHGR)
    /// - Returns: Tokenized Applesoft BASIC program
    static func generateSlideshow(fileNames: [String]) -> Data {
        // Simple slideshow with ~5 second delay between images
        // Press Q to quit, any other key to advance immediately
        // Filenames starting with * are DHGR images
        var lines: [String] = []

        let imageCount = fileNames.count

        lines.append("10 TEXT")
        lines.append("20 HOME")
        lines.append("30 PRINT \"BITPAST SLIDESHOW\"")
        lines.append("40 PRINT")
        lines.append("50 PRINT \"\(imageCount) IMAGE(S) ON DISK\"")
        lines.append("60 PRINT")
        lines.append("70 PRINT \"PRESS ANY KEY TO START\"")
        lines.append("80 PRINT \"Q = QUIT\"")
        lines.append("85 POKE -16368,0")
        lines.append("87 IF PEEK(-16384) < 128 THEN 87")
        lines.append("89 POKE -16368,0")

        var lineNum = 100

        for fileName in fileNames {
            let isDHGR = fileName.hasPrefix("*")
            let actualFileName = isDHGR ? String(fileName.dropFirst()) : fileName

            if isDHGR {
                // DHGR mode: Enable double hi-res and 80-column
                // AN3 off, HIRES on, MIXED off, PAGE1
                lines.append("\(lineNum) POKE 49246,0")       // AN3 off (enable DHGR)
                lines.append("\(lineNum + 2) POKE 49237,0")   // HIRES on
                lines.append("\(lineNum + 4) POKE 49234,0")   // MIXED off (full screen)
                lines.append("\(lineNum + 6) POKE 49236,0")   // PAGE1
                lines.append("\(lineNum + 8) POKE 49232,0")   // 80STORE off
                lines.append("\(lineNum + 10) PRINT CHR$(4);\"BLOAD \(actualFileName),A$2000\"")
            } else {
                // Standard HGR mode
                lines.append("\(lineNum) HGR")
                lines.append("\(lineNum + 2) POKE -16302,0")  // Full screen (no text)
                lines.append("\(lineNum + 10) PRINT CHR$(4);\"BLOAD \(actualFileName),A$2000\"")
            }

            // Wait loop (~5 seconds or keypress)
            lines.append("\(lineNum + 12) FOR T = 1 TO 50")
            lines.append("\(lineNum + 14) FOR W = 1 TO 100")
            lines.append("\(lineNum + 16) K = PEEK(-16384)")
            lines.append("\(lineNum + 18) IF K > 127 THEN POKE -16368,0")
            lines.append("\(lineNum + 20) IF K = 209 OR K = 241 THEN 900")
            lines.append("\(lineNum + 22) IF K > 127 THEN \(lineNum + 30)")
            lines.append("\(lineNum + 24) NEXT W")
            lines.append("\(lineNum + 26) NEXT T")
            lines.append("\(lineNum + 30) POKE -16368,0")
            lineNum += 40
        }

        // Loop back to beginning
        lines.append("\(lineNum) GOTO 100")
        lines.append("900 TEXT")
        lines.append("910 HOME")
        lines.append("920 PRINT \"SLIDESHOW ENDED\"")
        lines.append("930 END")

        let source = lines.joined(separator: "\n")
        return tokenize(source)
    }

    /// Generate a simple HELLO program that shows available images
    static func generateHello(fileNames: [String]) -> Data {
        var source = """
        10 HOME
        20 PRINT "BITPAST DISK"
        30 PRINT
        40 PRINT "IMAGES ON THIS DISK:"
        50 PRINT

        """

        var lineNum = 60
        for fileName in fileNames {
            source += "\(lineNum) PRINT \"  \(fileName)\"\n"
            lineNum += 10
        }

        source += """
        \(lineNum) PRINT
        \(lineNum + 10) PRINT "USE BLOAD TO LOAD IMAGES"
        \(lineNum + 20) PRINT "E.G.: HGR : BLOAD \(fileNames.first ?? "IMAGE"),A$2000"
        \(lineNum + 30) END
        """

        return tokenize(source)
    }
}
