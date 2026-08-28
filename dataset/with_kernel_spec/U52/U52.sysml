package 'Cytocentrifuge System' {
	private import ScalarValues::*;
	private import ISQ::*;

	package Definitions {
		attribute def RotationalSpeedValue :> Real;
		attribute def VibrationLevelValue :> Real;
		attribute def DurationValue :> Real;
		attribute def VolumeValue :> Real;
		attribute def PoreSizeValue :> Real;
		attribute def TorqueValue :> Real;

		attribute def StartCommand;
		attribute def SamplesLoaded;
		attribute def ResetCommand;
		attribute def EmergencyStopSignal;

		item def 'Liquid Biological Sample' {
			attribute volume : VolumeValue;
			attribute cellCount : Integer;
		}

		part def 'Microscope Slide' {
			attribute slideId : String;
		}

		part def 'Filter Card' {
			attribute poreSize : PoreSizeValue;
			attribute absorbentPadCapacity : VolumeValue;
		}

		part def 'Slide Carrier' {
			part slide : 'Microscope Slide';
		}

		part def 'Sample Chamber' {
			item 'liquid sample' : 'Liquid Biological Sample';
			part 'filter card' : 'Filter Card';
			part 'slide carrier' : 'Slide Carrier';
		}

		port def 'Motor Control Port' {
			in speedCommand : RotationalSpeedValue;
			out torque : TorqueValue;
		}

		port def 'Rotor Drive Port' {
			in torque : TorqueValue;
		}

		port def 'Panel Port' {
			in displayData : String;
			out startCommand : Boolean;
			out speedSelection : RotationalSpeedValue;
			out stopCommand : Boolean;
		}

		port def 'Safety Port' {
			out lidStatus : Boolean;
			out balanceStatus : Boolean;
			out vibrationLevel : VibrationLevelValue;
			out emergencyStop : Boolean;
		}

		port def 'Controller Port' {
			out motorSpeedCommand : RotationalSpeedValue;
			in motorFeedback : RotationalSpeedValue;
			out panelDisplay : String;
			in panelStart : Boolean;
			in panelSpeed : RotationalSpeedValue;
			in panelStop : Boolean;
			in safetyLid : Boolean;
			in safetyBalance : Boolean;
			in safetyVibration : VibrationLevelValue;
			in safetyEmergencyStop : Boolean;
		}

		port def 'Speed Feedback Port' {
			out currentSpeed : RotationalSpeedValue;
		}

		part def 'Rotor Assembly' {
			attribute maxSamples : Integer = 12;
			part 'sample chambers' : 'Sample Chamber'[0..12];
			port rotorDrivePort : 'Rotor Drive Port';
		}

		part def 'Drive Motor' {
			attribute maxSpeed : RotationalSpeedValue;
			attribute currentSpeed : RotationalSpeedValue;
			port motorDrivePort : 'Motor Control Port';
			port speedFeedbackPort : 'Speed Feedback Port';
		}

		part def 'User Panel' {
			attribute speedMode : String;
			port panelPort : 'Panel Port';
		}

		part def 'Safety System' {
			attribute lidLocked : Boolean;
			attribute rotorBalanced : Boolean;
			attribute vibrationThreshold : VibrationLevelValue;
			port safetyPort : 'Safety Port';
		}

		part def 'Controller Unit' {
			port controlPort : 'Controller Port';
		}

		state def 'Cytocentrifuge States';

		action def 'Prepare Samples' {
			in item 'raw sample' : 'Liquid Biological Sample';
			out item 'prepared slide' : 'Microscope Slide';
		}

		action def 'Concentrate Cells' {
			in item 'liquid sample' : 'Liquid Biological Sample';
			in item 'filter card' : 'Filter Card';
			in item 'slide carrier' : 'Slide Carrier';
			out item 'prepared slide' : 'Microscope Slide';
		}

		action def 'Accelerate Rotor';
		action def 'Decelerate Rotor';
		action def 'Maintain Speed';
		action def 'Set Spin Timer';

		requirement def 'Shall Concentrate Cells' {
			doc /* The system shall concentrate cells from a liquid biological sample onto a defined area of a microscope slide. */
		}

		requirement def 'Shall Process Twelve Samples' {
			doc /* The rotor assembly shall hold and process up to 12 samples simultaneously. */
		}

		requirement def 'Shall Prevent Unsafe Operation' {
			doc /* The safety system shall prevent motor operation unless the lid is locked and the rotor is balanced. */
		}

		requirement def 'Shall Provide Speed Modes' {
			doc /* The user panel shall allow selection of low, medium, or high speed modes. */
		}

		part def 'Cytocentrifuge' {
			part rotorAssembly : 'Rotor Assembly';
			part driveMotor : 'Drive Motor';
			part controllerUnit : 'Controller Unit';
			part userPanel : 'User Panel';
			part safetySystem : 'Safety System';
		}
	}

	package Usages {
		private import Definitions::*;

		part 'Cytocentrifuge' {
			attribute spinDuration : DurationValue = 600;

			part rotorAssembly : 'Rotor Assembly';
			part driveMotor : 'Drive Motor';
			part controllerUnit : 'Controller Unit';
			part userPanel : 'User Panel';
			part safetySystem : 'Safety System';

			requirement 'cell concentration req' : 'Shall Concentrate Cells';
			requirement 'twelve sample req' : 'Shall Process Twelve Samples';
			requirement 'safety req' : 'Shall Prevent Unsafe Operation';
			requirement 'speed mode req' : 'Shall Provide Speed Modes';

			perform action 'prepare samples' : 'Prepare Samples' {
				action 'concentrate cells' : 'Concentrate Cells';
			}

			action 'accelerate rotor' : 'Accelerate Rotor';
			action 'decelerate rotor' : 'Decelerate Rotor';
			action 'maintain speed' : 'Maintain Speed';
			action 'set spin timer' : 'Set Spin Timer';

			connect driveMotor.motorDrivePort.torque to rotorAssembly.rotorDrivePort.torque;
			connect controllerUnit.controlPort.motorSpeedCommand to driveMotor.motorDrivePort.speedCommand;
			connect driveMotor.speedFeedbackPort.currentSpeed to controllerUnit.controlPort.motorFeedback;
			connect userPanel.panelPort.startCommand to controllerUnit.controlPort.panelStart;
			connect userPanel.panelPort.speedSelection to controllerUnit.controlPort.panelSpeed;
			connect userPanel.panelPort.stopCommand to controllerUnit.controlPort.panelStop;
			connect controllerUnit.controlPort.panelDisplay to userPanel.panelPort.displayData;
			connect safetySystem.safetyPort.lidStatus to controllerUnit.controlPort.safetyLid;
			connect safetySystem.safetyPort.balanceStatus to controllerUnit.controlPort.safetyBalance;
			connect safetySystem.safetyPort.vibrationLevel to controllerUnit.controlPort.safetyVibration;
			connect safetySystem.safetyPort.emergencyStop to controllerUnit.controlPort.safetyEmergencyStop;

			exhibit state 'cytocentrifuge states' : 'Cytocentrifuge States' {
				entry; then idle;
				state idle;
				accept StartCommand
					if safetySystem.lidLocked and safetySystem.rotorBalanced
					then loading;
				state loading;
				accept SamplesLoaded
					then accelerating;
				state accelerating {
					do 'accelerate rotor';
				}
				accept when driveMotor.currentSpeed >= userPanel.panelPort.speedSelection
					then spinning;
				state spinning {
					entry 'set spin timer';
					do 'maintain speed';
				}
				accept after spinDuration
					then decelerating;
				state decelerating {
					do 'decelerate rotor';
				}
				accept when driveMotor.currentSpeed == 0.0
					then complete;
				state complete;
				accept ResetCommand
					then idle;
				accept EmergencyStopSignal
					then decelerating;
			}
		}
	}
}
