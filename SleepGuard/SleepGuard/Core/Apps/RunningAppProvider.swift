import Foundation

protocol RunningAppProvider {
    func runningApplications() -> [RunningAppInfo]
}
