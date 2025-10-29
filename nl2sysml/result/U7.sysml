// Describe a car that includes an electric motor, battery pack, and regenerative braking.
package 'Electric Car System' {
	part def Car {
		part electricMotor : ElectricMotor;
		part batteryPack : BatteryPack;
		part regenerativeBraking : RegenerativeBraking;
	}
	part def ElectricMotor;
	part def BatteryPack;
	part def RegenerativeBraking;
}
