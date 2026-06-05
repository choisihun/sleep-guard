import Foundation

struct RecommendationEngine {
    func recommendations(
        drainPercent: Int,
        drainPerHour: Double,
        durationSeconds: TimeInterval = 0,
        darkWakeCount: Int,
        tcpKeepAliveCount: Int,
        bluetoothDelayCount: Int,
        usbCWakeCount: Int = 0,
        assertionProcesses: [String],
        runningProcessNames: [String]
    ) -> [String] {
        var output: [String] = []
        if drainPerHour > BatteryDrainThresholds.highDrainPerHour {
            output.append("시간당 배터리 소모가 높은 편입니다. 관리 앱을 종료한 뒤 다시 측정해보세요.")
        } else if drainPercent >= BatteryDrainThresholds.highTotalDrainPercent {
            output.append("총 배터리 감소량이 큽니다. 긴 수면 중 누적 방전이 발생했을 수 있으니 Wake Requests, 네트워크 유지, Bluetooth 지연 항목을 확인하세요.")
        } else if BatteryDrainThresholds.isLongSleepNotableDrain(drainPercent: drainPercent, durationSeconds: durationSeconds) {
            output.append("장시간 수면에서 총 배터리 감소량이 큽니다. 배터리 수면 최적화를 켜고 같은 조건으로 다시 측정하세요.")
        } else if drainPercent >= BatteryDrainThresholds.notableTotalDrainPercent {
            output.append("총 배터리 감소량이 평소보다 큰 편입니다. 같은 조건으로 한 번 더 측정해 기준값과 비교하세요.")
        }
        if darkWakeCount > 20 {
            output.append("잠자기 중 짧은 깨움이 많았습니다. Wake Requests 항목을 확인하세요.")
        }
        if tcpKeepAliveCount > 0 {
            output.append("네트워크 유지 동작이 감지되었습니다. 배터리 상태에서는 불필요한 네트워크 앱을 종료하고 배터리 수면 최적화를 켜는 것이 좋습니다.")
        }
        if bluetoothDelayCount > 5 {
            output.append("Bluetooth sleep 지연이 반복되었습니다. Bluetooth 주변기기를 분리하고 다시 확인하세요.")
        }
        if usbCWakeCount > 0 {
            output.append("USB-C/외부 장치 wake 신호가 감지되었습니다. 잠자기 전 USB-C 허브, 충전기, 외장 디스플레이, 저장장치를 분리하거나 전원이 안정적인 포트로 바꿔 다시 측정하세요.")
        }
        if !assertionProcesses.isEmpty {
            output.append("잠자기를 막는 assertion 프로세스가 감지되었습니다. 해당 앱을 관리 대상으로 추가해 다시 측정하세요.")
        }
        if !runningProcessNames.isEmpty {
            output.append("실행 중인 앱의 배터리 영향 상위 목록에서 종료 대상을 선택해보세요.")
        }
        if output.isEmpty {
            output.append("큰 수면 방해 요소는 보이지 않습니다. 같은 조건에서 한 번 더 측정해 기준값을 만들어두세요.")
        }
        return output
    }
}
