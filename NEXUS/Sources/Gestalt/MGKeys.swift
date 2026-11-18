import Foundation
import CryptoKit

/// MobileGestalt 键名混淆算法（来自 GitHub：PoomSmart/MGKeys 的说明）：
/// base64( MD5("MGCopyAnswer" + 键名) ) 去掉末尾两个字符。
/// 本应用在构建期用 Python 对下方每个名称做过校验：与 MGKeys 的 mapping-gestalt.h 中的哈希逐项一致。
enum MGKeyCatalog {
    static func hash(_ name: String) -> String {
        let digest = Insecure.MD5.hash(data: Data(("MGCopyAnswer" + name).utf8))
        return String(Data(digest).base64EncodedString().dropLast(2))
    }

    /// 仅记录名称（哈希运行时计算，避免手抄出错）。名称均出自 MGKeys 映射表。
    static let names: [String] = [
        "ProductType", "ProductVersion", "BuildVersion", "HWModelStr", "DeviceName", "device-name", "DeviceClass", "ModelNumber",
        "MarketingProductName", "marketing-name", "marketing-soc-name", "ChipID", "BoardId", "DeviceColor", "RegionCode",
        "DeviceMemorySize", "OLEDDisplay", "DeviceCornerRadius", "IsSimulator", "SerialNumber", "UniqueDeviceID",
        "InternationalMobileEquipmentIdentity", "main-screen-scale", "main-screen-width", "main-screen-height",
        "ArtworkTraits", "ArtworkTraitDisplayGamut",
        "DeviceSupportsDynamicIsland", "DeviceSupportsAlwaysOnDisplay", "DeviceSupportsAlwaysOnTime", "DeviceSupportsAODVibrancy",
        "DeviceSupportsAlwaysOnDisplayFlipbook", "AlwaysOnDisplayMaxMemory", "DeviceDisablesAODByDefault",
        "DeviceSupportsApplePencil", "CameraButtonCapability", "CameraButtonCGRect", "RingerButtonCapability", "RingerButtonCGRect",
        "DeviceSupportsGenerativeModelSystems", "generative-model-systems", "IsSolariumLowPerformanceDevice",
        "DeviceSupportsEnhancedMultitasking", "DeviceSupportsSingleDisplayEnhancedMultitasking",
        "DeviceSupportsHDRPhotoDisplay", "DeviceSupportsExternalHDR", "DeviceSupportsTapToWake", "DeviceSupportsBootChime",
        "DeviceSupports80ChargeLimit", "DeviceSupportsCollisionSOS", "DeviceSupportsLiveActivities", "DeviceSupportsPhotosInpainting",
        "DeviceSupportsLandscapeFaceID", "DeviceSupportsUSBTypeC", "ResearchFuse", "StoreDemoMode", "RegionalBehaviorShutterClick",
        "haptics", "nfc", "lidar-scanner", "touch-id",
    ]

    static let hashToName: [String: String] = Dictionary(uniqueKeysWithValues: names.map { (hash($0), $0) })

    static func name(forHash h: String) -> String? { hashToName[h] }
}
