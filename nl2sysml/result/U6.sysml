// Specify a water pump system that activates below 30% and deactivates at 90% tank level.
package 'Water Pump System' {
    private import ScalarValues::*;

    attribute def TankLevel : Real;

    part def WaterPump;
    part def WaterTank;

    action def MonitorTankLevel {
        out level : TankLevel;
    }

    action def ActivatePump;
    action def DeactivatePump;

    action def ManagePumpSystem {
        attribute pumpIsActive : Boolean = false;

        loop {
            action monitor : MonitorTankLevel {
                out currentLevel : TankLevel;
            }

            if not pumpIsActive and monitor.currentLevel < 30 {
                then action activate : ActivatePump;
                then assign pumpIsActive = true;
            }
            else if pumpIsActive and monitor.currentLevel >= 90 {
                then action deactivate : DeactivatePump;
                then assign pumpIsActive = false;
            }
        }
    }
}
