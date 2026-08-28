package 'Automated Birthing Chair System' {
    private import ScalarValues::*;

    package Units {
        unit def deg;
        unit def mm;
        unit def kg;
        unit def Pa;
        unit def s;
    }

    package ValueTypes {
        private import Units::*;
        attribute def Angle :> Real { unit = deg; }
        attribute def Distance :> Real { unit = mm; }
        attribute def Mass :> Real { unit = kg; }
        attribute def Pressure :> Real { unit = Pa; }
        attribute def Time :> Real { unit = s; }
    }

    package Enumerations {
        enum def CommandKind {
            startPositioning;
            adjustPosition;
            emergencyStop;
            reset;
        }
    }

    package Ports {
        private import ValueTypes::*;
        private import Enumerations::*;
        port def MotorControlPort {
            in command : Real;
            in speed : Real;
        }
        port def SensorFeedbackPort {
            out angle : Angle;
            out load : Mass;
        }
        port def LoadSensorPort {
            out pressure : Pressure;
            out weight : Mass;
        }
        port def CommandPort {
            in command : CommandKind;
            out status : Boolean;
        }
    }

    package Definitions {
        private import Ports::*;
        private import ValueTypes::*;
        private import Enumerations::*;

        part def StructuralFrame {
            attribute loadCapacity : Mass = 250;
            part stabilizer[4];
        }

        part def BackrestModule {
            port motorControl : MotorControlPort;
            port sensorFeedback : SensorFeedbackPort;
            attribute reclineAngle : Angle;
            part padding;
            part motor;
            part lockingMechanism;
        }

        part def SeatModule {
            port actuatorControl : MotorControlPort;
            port sensorFeedback : SensorFeedbackPort;
            port loadSensorOut : LoadSensorPort;
            attribute tiltAngle : Angle;
            part foamCushioning;
            part deliveryOpening;
            part actuator;
        }

        part def LegSupportUnit {
            port angleMotorControl : MotorControlPort;
            port angleSensorFeedback : SensorFeedbackPort;
            port spreadMotorControl : MotorControlPort;
            port spreadSensorFeedback : SensorFeedbackPort;
            part stirrup;
        }

        part def LegSupportModule {
            part leftLegSupport : LegSupportUnit;
            part rightLegSupport : LegSupportUnit;
            part spreadActuator;
        }

        part def ArmrestUnit {
            port heightMotorControl : MotorControlPort;
            port heightSensorFeedback : SensorFeedbackPort;
            part grip;
        }

        part def ArmrestModule {
            part leftArmrest : ArmrestUnit;
            part rightArmrest : ArmrestUnit;
        }

        part def ControlUnit {
            port commandIn : CommandPort;
            port backrestControl : ~MotorControlPort;
            port seatControl : ~MotorControlPort;
            port leftLegAngleControl : ~MotorControlPort;
            port rightLegAngleControl : ~MotorControlPort;
            port leftLegSpreadControl : ~MotorControlPort;
            port rightLegSpreadControl : ~MotorControlPort;
            port leftArmrestControl : ~MotorControlPort;
            port rightArmrestControl : ~MotorControlPort;

            port backrestFeedback : ~SensorFeedbackPort;
            port seatFeedback : ~SensorFeedbackPort;
            port leftLegAngleFeedback : ~SensorFeedbackPort;
            port rightLegAngleFeedback : ~SensorFeedbackPort;
            port leftLegSpreadFeedback : ~SensorFeedbackPort;
            port rightLegSpreadFeedback : ~SensorFeedbackPort;
            port leftArmrestFeedback : ~SensorFeedbackPort;
            port rightArmrestFeedback : ~SensorFeedbackPort;

            port loadSensorIn : ~LoadSensorPort;

            part microcontroller;
            part positionSensor;
            part loadSensor;

            attribute commandReceived : Boolean;
            attribute targetReached : Boolean;
            attribute unsafeLoad : Boolean;
            attribute resetReceived : Boolean;
        }
    }

    package Requirements {
        private import ValueTypes::*;

        requirement def PositionSupport {
            doc /* The system shall provide adjustable, gravity-assisted positional support. */
        }
        requirement def SafetyMonitoring {
            doc /* The system shall continuously monitor weight and pressure distribution. */
        }
        requirement def EmergencyHalt {
            doc /* The system shall halt all movement and lock components in place during an emergency. */
        }
        requirement def ClinicalAccess {
            doc /* The chair shall provide necessary clinical access for medical staff. */
        }
        requirement def LoadCapacity {
            doc /* The chair shall support a maximum load of 250 kg. */
            attribute maxLoad : Mass = 250;
        }
    }

    package Usages {
        private import Definitions::*;
        private import Requirements::*;
        private import Ports::*;

        requirement pos : PositionSupport;
        requirement safe : SafetyMonitoring;
        requirement halt : EmergencyHalt;
        requirement access : ClinicalAccess;
        requirement load : LoadCapacity;

        part automatedBirthingChair {
            port externalCommand : ~CommandPort;

            part chairFrame : StructuralFrame;
            part backrest : BackrestModule;
            part seat : SeatModule;
            part legSupport : LegSupportModule;
            part armrest : ArmrestModule;
            part controller : ControlUnit;

            connect externalCommand to controller.commandIn;
            connect controller.backrestControl to backrest.motorControl;
            connect controller.seatControl to seat.actuatorControl;
            connect controller.leftLegAngleControl to legSupport.leftLegSupport.angleMotorControl;
            connect controller.rightLegAngleControl to legSupport.rightLegSupport.angleMotorControl;
            connect controller.leftLegSpreadControl to legSupport.leftLegSupport.spreadMotorControl;
            connect controller.rightLegSpreadControl to legSupport.rightLegSupport.spreadMotorControl;
            connect controller.leftArmrestControl to armrest.leftArmrest.heightMotorControl;
            connect controller.rightArmrestControl to armrest.rightArmrest.heightMotorControl;

            connect backrest.sensorFeedback to controller.backrestFeedback;
            connect seat.sensorFeedback to controller.seatFeedback;
            connect legSupport.leftLegSupport.angleSensorFeedback to controller.leftLegAngleFeedback;
            connect legSupport.rightLegSupport.angleSensorFeedback to controller.rightLegAngleFeedback;
            connect legSupport.leftLegSupport.spreadSensorFeedback to controller.leftLegSpreadFeedback;
            connect legSupport.rightLegSupport.spreadSensorFeedback to controller.rightLegSpreadFeedback;
            connect armrest.leftArmrest.heightSensorFeedback to controller.leftArmrestFeedback;
            connect armrest.rightArmrest.heightSensorFeedback to controller.rightArmrestFeedback;
            connect seat.loadSensorOut to controller.loadSensorIn;

            state def operation {
                state standby;
                state positioning;
                state activeSupport;
                state emergency;

                transition standby to positioning when controller.commandReceived;
                transition positioning to activeSupport when controller.targetReached;
                transition activeSupport to positioning when controller.commandReceived;
                transition standby to emergency when controller.unsafeLoad;
                transition positioning to emergency when controller.unsafeLoad;
                transition activeSupport to emergency when controller.unsafeLoad;
                transition emergency to standby when controller.resetReceived;
            }
        }

        satisfy pos by automatedBirthingChair;
        satisfy safe by automatedBirthingChair;
        satisfy halt by automatedBirthingChair;
        satisfy access by automatedBirthingChair;
        satisfy load by automatedBirthingChair.chairFrame;
    }
}
