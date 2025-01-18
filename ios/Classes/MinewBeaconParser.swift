import CoreBluetooth

class MinewBeaconParser {
    static func parseManufacturerData(_ data: Data) -> [String: Any]? {
        // Verificar si es un beacon Minew (company ID)
        guard data.count >= 2 else { return nil }
        
        var frames: [[String: Any]] = []
        var currentIndex = 2 // Skip company ID
        
        while currentIndex < data.count {
            guard currentIndex + 1 < data.count else { break }
            let frameLength = Int(data[currentIndex])
            let frameType = data[currentIndex + 1]
            
            // Frame tipo temperatura (0x01)
            if frameType == 0x01 {
                let tempData = data.subdata(in: (currentIndex + 2)..<(currentIndex + 4))
                let tempValue = Float(CFSwapInt16BigToHost(tempData.withUnsafeBytes { $0.load(as: UInt16.self) })) / 100.0
                
                frames.append([
                    "type": "FrameTempSensor",
                    "temp": tempValue
                ])
            }
            
            currentIndex += frameLength + 1
        }
        
        return ["advFrames": frames]
    }
} 