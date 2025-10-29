// Define the basic structure of a security system with a door sensor and an alarm.
package 'Security System' {
	part def SecuritySystem;
	part def DoorSensor;
	part def Alarm;

	part homeSecurity : SecuritySystem {
		part sensor : DoorSensor;
		part siren : Alarm;
	}
}
