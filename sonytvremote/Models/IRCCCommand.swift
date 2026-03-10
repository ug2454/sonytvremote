import Foundation

enum IRCCCommand: String, CaseIterable {
    // Power
    case power          = "AAAAAQAAAAEAAAAVAw=="
    case powerOff       = "AAAAAQAAAAEAAAAvAw=="

    // Navigation
    case up             = "AAAAAQAAAAEAAAB0Aw=="
    case down           = "AAAAAQAAAAEAAAB1Aw=="
    case left           = "AAAAAQAAAAEAAAA0Aw=="
    case right          = "AAAAAQAAAAEAAAAzAw=="  // Alternative code that works for some Sony TV models
    case confirm        = "AAAAAQAAAAEAAABlAw=="

    // System
    case home           = "AAAAAQAAAAEAAABgAw=="
    case back           = "AAAAAgAAAJcAAAAjAw=="
    case exit           = "AAAAAQAAAAEAAABjAw=="
    case options        = "AAAAAgAAAJcAAAA2Aw=="
    case info           = "AAAAAQAAAAEAAAB7Aw=="

    // Volume
    case volumeUp       = "AAAAAQAAAAEAAAASAw=="
    case volumeDown     = "AAAAAQAAAAEAAAATAw=="
    case mute           = "AAAAAQAAAAEAAAAUAw=="

    // Channel
    case channelUp      = "AAAAAQAAAAEAAAAQAw=="
    case channelDown    = "AAAAAQAAAAEAAAARAw=="

    // Media Playback
    case play           = "AAAAAgAAAJcAAAAaAw=="
    case pause          = "AAAAAgAAAJcAAAAZAw=="
    case stop           = "AAAAAgAAAJcAAAAYAw=="
    case fastForward    = "AAAAAgAAAJcAAAAcAw=="
    case rewind         = "AAAAAgAAAJcAAAAbAw=="
    case prev           = "AAAAAgAAAJcAAAA8Aw=="
    case next           = "AAAAAgAAAJcAAAA9Aw=="

    // Input
    case input          = "AAAAAQAAAAEAAAAlAw=="
    case hdmi1          = "AAAAAgAAABoAAABaAw=="
    case hdmi2          = "AAAAAgAAABoAAABbAw=="
    case hdmi3          = "AAAAAgAAABoAAABcAw=="
    case hdmi4          = "AAAAAgAAABoAAABdAw=="

    // Color Buttons
    case red            = "AAAAAgAAAJcAAAAlAw=="
    case green          = "AAAAAgAAAJcAAAAkAw=="
    case yellow         = "AAAAAgAAAJcAAAAmAw=="
    case blue           = "AAAAAgAAAJcAAAAnAw=="

    // Numbers
    case num0           = "AAAAAQAAAAEAAAAJAw=="
    case num1           = "AAAAAQAAAAEAAAAAAw=="
    case num2           = "AAAAAQAAAAEAAAABAw=="
    case num3           = "AAAAAQAAAAEAAAACAw=="
    case num4           = "AAAAAQAAAAEAAAADAw=="
    case num5           = "AAAAAQAAAAEAAAAEAw=="
    case num6           = "AAAAAQAAAAEAAAAFAw=="
    case num7           = "AAAAAQAAAAEAAAAGAw=="
    case num8           = "AAAAAQAAAAEAAAAHAw=="
    case num9           = "AAAAAQAAAAEAAAAIAw=="

    // Subtitles / Audio
    case subtitle       = "AAAAAgAAAJcAAAAoAw=="
    case audio          = "AAAAAQAAAAEAAAAXAw=="

    // Picture
    case picOff         = "AAAAAQAAAAEAAAA+Aw=="
    case aspect         = "AAAAAgAAAKQAAAADAw=="

    // Streaming
    case netflix        = "AAAAAgAAABoAAAB8Aw=="
    case youtube        = "AAAAAgAAAMQAAABHAw=="
    case prime          = "AAAAAgAAAMQAAAB5Aw=="
    
    // Maps to the command name returned by getRemoteControllerInfo
    var tvName: String {
        switch self {
        case .power:        return "Power"
        case .powerOff:     return "PowerOff"
        case .up:           return "Up"
        case .down:         return "Down"
        case .left:         return "Left"
        case .right:        return "Right"
        case .confirm:      return "Confirm"
        case .home:         return "Home"
        case .back:         return "Return"
        case .exit:         return "Exit"
        case .options:      return "Options"
        case .info:         return "Display"
        case .volumeUp:     return "VolumeUp"
        case .volumeDown:   return "VolumeDown"
        case .mute:         return "Mute"
        case .channelUp:    return "ChannelUp"
        case .channelDown:  return "ChannelDown"
        case .play:         return "Play"
        case .pause:        return "Pause"
        case .stop:         return "Stop"
        case .fastForward:  return "Forward"
        case .rewind:       return "Rewind"
        case .prev:         return "Prev"
        case .next:         return "Next"
        case .input:        return "Input"
        case .hdmi1:        return "Hdmi1"
        case .hdmi2:        return "Hdmi2"
        case .hdmi3:        return "Hdmi3"
        case .hdmi4:        return "Hdmi4"
        case .red:          return "Red"
        case .green:        return "Green"
        case .yellow:       return "Yellow"
        case .blue:         return "Blue"
        case .num0:         return "Num0"
        case .num1:         return "Num1"
        case .num2:         return "Num2"
        case .num3:         return "Num3"
        case .num4:         return "Num4"
        case .num5:         return "Num5"
        case .num6:         return "Num6"
        case .num7:         return "Num7"
        case .num8:         return "Num8"
        case .num9:         return "Num9"
        case .subtitle:     return "SubTitle"
        case .audio:        return "Audio"
        case .picOff:       return "PicOff"
        case .aspect:       return "Aspect"
        case .netflix:      return "Netflix"
        case .youtube:      return "YouTube"
        case .prime:        return "Amazon"
        }
    }
}

struct TVApp: Identifiable {
    let id = UUID()
    let title: String
    let uri: String
    let iconURL: String?
}

struct TVInput: Identifiable {
    let id = UUID()
    let title: String
    let uri: String
    let icon: String
    let status: String
}

struct VolumeInfo {
    let target: String
    let volume: Int
    let minVolume: Int
    let maxVolume: Int
    let mute: Bool
}
