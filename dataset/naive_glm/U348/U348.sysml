package PatientLiftSystem {
    import ScalarValues::*;
    import ISQ::*;
    import ISQSpace::*;
    import ISQMass::*;
    import ISQElectricity::*;
    import ISQTime::*;

    // ---------- Value Types ----------
    def MassValue :> MassValue;
    value def WeightUnit :> MassUnit;
    value def WeightMeasure :> MassValue { redefines unit = WeightUnit; }
    
    value def HeightUnit :> LengthUnit;
    value def HeightMeasure :> LengthValue { redefines unit = HeightUnit; }
    
    value def VoltageMeasure :> ElectricPotentialValue;
    value def CurrentMeasure :> ElectricCurrentValue;
    value def EnergyMeasure :> EnergyValue;
    value def ChargeMeasure :> ElectricChargeValue;
    value def ForceMeasure :> ForceValue;
    value def SpeedMeasure :> SpeedValue;
    value def AngleMeasure :> PlaneAngleValue;
    value def PercentMeasure :> Real;
    value def PressureMeasure :> PressureValue;

    // ---------- Item Types ----------
    item def PowerSignal {
        attribute voltage : VoltageMeasure;
        attribute current : CurrentMeasure;
    }
    
    item def ControlCommand {
        attribute command : ControlCommandEnum;
    }
    enum ControlCommandEnum { raise, lower, stop, emergencyStop }
    
    item def WeightReading {
        attribute measuredWeight : WeightMeasure;
    }
    
    item def HeightReading {
        attribute measuredHeight : HeightMeasure;
    }
    
    item def BatteryStatus {
        attribute stateOfCharge : PercentMeasure;
        attribute voltage : VoltageMeasure;
    }
    
    item def ActuatorCommand {
        attribute direction : ActuatorDirectionEnum;
        attribute speed : SpeedMeasure;
    }
    enum ActuatorDirectionEnum { extend, retract, halt }
    
    item def LoadAlert {
        attribute overload : Boolean;
        attribute measuredWeight : WeightMeasure;
    }
    
    item def EmergencyStopSignal {
        attribute triggered : Boolean;
    }

    // ---------- Port Definitions ----------
    port def PowerPort {
        out power : PowerSignal;
    }
    
    port def ControlCommandPort {
        out command : ControlCommand;
    }
    
    port def WeightReadingPort {
        out reading : WeightReading;
    }
    
    port def HeightReadingPort {
        out reading : HeightReading;
    }
    
    port def BatteryStatusPort {
        out status : BatteryStatus;
    }
    
    port def ActuatorCommandPort {
        out cmd : ActuatorCommand;
    }
    
    port def EmergencyStopPort {
        out signal : EmergencyStopSignal;
    }
    
    port def LoadAlertPort {
        out alert : LoadAlert;
    }

    // ---------- Part Definitions ----------
    part def CasterWheel {
        attribute hasBrake : Boolean;
        attribute wheelDiameter : HeightMeasure;
        port def BrakeControlPort {
            in engage : Boolean;
        }
        port brakePort : BrakeControlPort;
        
        action def ApplyBrake {
            in engage : Boolean;
        }
    }
    
    part def BaseFrame {
        attribute frameLength : HeightMeasure;
        attribute frameWidth : HeightMeasure;
        part frontLeftWheel : CasterWheel { redefines hasBrake = false; }
        part frontRightWheel : CasterWheel { redefines hasBrake = false; }
        part rearLeftWheel : CasterWheel { redefines hasBrake = true; }
        part rearRightWheel : CasterWheel { redefines hasBrake = true; }
    }
    
    part def Mast {
        attribute mastHeight : HeightMeasure;
        attribute mastMaterial : String;
    }
    
    part def ElectricActuator {
        attribute maxForce : ForceMeasure;
        attribute maxSpeed : SpeedMeasure;
        attribute strokeLength : HeightMeasure;
        port cmdPort : ActuatorCommandPort;
        port powerPort : PowerPort;
        
        action def Extend {
            in speed : SpeedMeasure;
        }
        action def Retract {
            in speed : SpeedMeasure;
        }
        action def Halt;
    }
    
    part def LiftingArm {
        attribute armLength : HeightMeasure;
        attribute maxArticulationAngle : AngleMeasure;
        part actuator : ElectricActuator;
        port attachmentPoint;
    }
    
    part def PendantControl {
        attribute buttonCount : Integer;
        port commandPort : ControlCommandPort;
        
        action def PressRaise;
        action def PressLower;
        action def PressStop;
    }
    
    part def ControlModule {
        attribute maxSafeLoad : WeightMeasure;
        attribute maxHeight : HeightMeasure;
        attribute minHeight : HeightMeasure;
        port commandIn : ControlCommandPort;
        port weightIn : WeightReadingPort;
        port heightIn : HeightReadingPort;
        port batteryIn : BatteryStatusPort;
        port estopIn : EmergencyStopPort;
        port actuatorOut : ActuatorCommandPort;
        port loadAlertOut : LoadAlertPort;
        
        action def ProcessCommands {
            in cmd : ControlCommand;
            in weight : WeightReading;
            in height : HeightReading;
            in estop : EmergencyStopSignal;
            out actuatorCmd : ActuatorCommand;
        }
        
        action def CheckOverload {
            in weight : WeightReading;
            out alert : LoadAlert;
        }
    }
    
    part def LoadCell {
        attribute maxCapacity : WeightMeasure;
        attribute accuracy : WeightMeasure;
        port readingOut : WeightReadingPort;
        
        action def MeasureWeight {
            out reading : WeightReading;
        }
    }
    
    part def HeightSensor {
        attribute range : HeightMeasure;
        attribute resolution : HeightMeasure;
        port readingOut : HeightReadingPort;
        
        action def MeasureHeight {
            out reading : HeightReading;
        }
    }
    
    part def EmergencyStopButton {
        attribute location : String;
        port signalOut : EmergencyStopPort;
        
        action def Trigger {
            out signal : EmergencyStopSignal;
        }
    }
    
    part def RechargeableBattery {
        attribute nominalVoltage : VoltageMeasure;
        attribute capacity : ChargeMeasure;
        attribute maxEnergy : EnergyMeasure;
        attribute stateOfCharge : PercentMeasure;
        port statusOut : BatteryStatusPort;
        port powerOut : PowerPort;
        
        action def Discharge {
            out power : PowerSignal;
        }
        action def Recharge;
    }
    
    part def PatientSling {
        attribute material : String;
        attribute maxLoad : WeightMeasure;
        attribute attachmentType : String;
        attribute isDetachable : Boolean;
    }
    
    part def PatientLift {
        attribute systemWeight : WeightMeasure;
        attribute maxPatientWeight : WeightMeasure;
        
        part baseFrame : BaseFrame;
        part mast : Mast;
        part liftingArm : LiftingArm;
        part pendant : PendantControl;
        part controller : ControlModule;
        part loadCell : LoadCell;
        part heightSensor : HeightSensor;
        part estopButton : EmergencyStopButton;
        part battery : RechargeableBattery;
        part sling : PatientSling;
        
        // Connections
        connection pendantToController : ControlCommand connect pendant.commandPort to controller.commandIn;
        connection loadCellToController : WeightReading connect loadCell.readingOut to controller.weightIn;
        connection heightSensorToController : HeightReading connect heightSensor.readingOut to controller.heightIn;
        connection batteryToController : BatteryStatus connect battery.statusOut to controller.batteryIn;
        connection estopToController : EmergencyStopSignal connect estopButton.signalOut to controller.estopIn;
        connection controllerToActuator : ActuatorCommand connect controller.actuatorOut to liftingArm.actuator.cmdPort;
        connection batteryToActuator : PowerSignal connect battery.powerOut to liftingArm.actuator.powerPort;
        connection controllerLoadAlert : LoadAlert connect controller.loadAlertOut to liftingArm.actuator.cmdPort;
        
        // State Machine
        state def LiftStates {
            entry; exit;
            
            state standby {
                entry action;
                transition standby_to_raising first standby if (controller.commandIn.command.command == ControlCommandEnum::raise) then raising;
            }
            
            state raising {
                entry action {
                    liftingArm.actuator.Extend();
                }
                transition raising_to_lowering first raising if (controller.commandIn.command.command == ControlCommandEnum::lower) then lowering;
                transition raising_to_locked first raising if (heightSensor.readingOut.reading.measuredHeight >= controller.maxHeight) then lockedElevated;
                transition raising_to_standby first raising if (controller.commandIn.command.command == ControlCommandEnum::stop) then standby;
                transition any_to_estop first raising if (estopButton.signalOut.signal.triggered == true) then emergencyHalted;
            }
            
            state lowering {
                entry action {
                    liftingArm.actuator.Retract();
                }
                transition lowering_to_raising first lowering if (controller.commandIn.command.command == ControlCommandEnum::raise) then raising;
                transition lowering_to_standby first lowering if (controller.commandIn.command.command == ControlCommandEnum::stop) then standby;
                transition lowering_to_standby2 first lowering if (heightSensor.readingOut.reading.measuredHeight <= controller.minHeight) then standby;
                transition any_to_estop2 first lowering if (estopButton.signalOut.signal.triggered == true) then emergencyHalted;
            }
            
            state lockedElevated {
                entry action {
                    liftingArm.actuator.Halt();
                }
                transition locked_to_lowering first lockedElevated if (controller.commandIn.command.command == ControlCommandEnum::lower) then lowering;
                transition any_to_estop3 first lockedElevated if (estopButton.signalOut.signal.triggered == true) then emergencyHalted;
            }
            
            state emergencyHalted {
                entry action {
                    liftingArm.actuator.Halt();
                }
                transition estop_to_standby first emergencyHalted if (estopButton.signalOut.signal.triggered == false && controller.commandIn.command.command == ControlCommandEnum::stop) then standby;
            }
            
            transition init_to_standby first initial then standby;
        }
        
        exhibit state behavior : LiftStates;
    }

    // ---------- Requirements ----------
    requirement def PatientLiftRequirements {
        doc /* Mobile, battery-powered patient lift system for safe transfer of individuals with limited mobility. */
    }
    
    requirement MobileOperation :> PatientLiftRequirements {
        doc /* The system shall be mobile and battery-powered, operating without tethering to a wall outlet. */
        subject patientLift : PatientLift;
        assume battery.stateOfCharge > 0.0;
    }
    
    requirement BaseStability :> PatientLiftRequirements {
        doc /* The system shall have a stable base frame with four caster wheels, two of which have brakes. */
        subject baseFrame : BaseFrame;
        require baseFrame.rearLeftWheel.hasBrake == true;
        require baseFrame.rearRightWheel.hasBrake == true;
        require baseFrame.frontLeftWheel.hasBrake == false;
        require baseFrame.frontRightWheel.hasBrake == false;
    }
    
    requirement VerticalMastSupport :> PatientLiftRequirements {
        doc /* A vertical mast shall rise from the base and support the main lifting mechanism. */
        subject mast : Mast;
        require mast.mastHeight > 0.0 [m];
    }
    
    requirement ArticulatedLiftingArm :> PatientLiftRequirements {
        doc /* An articulated lifting arm powered by an electric actuator shall perform the lifting function. */
        subject liftingArm : LiftingArm;
        require liftingArm.actuator.maxForce > 0.0 [N];
        require liftingArm.actuator.strokeLength > 0.0 [m];
    }
    
    requirement PendantControlReq :> PatientLiftRequirements {
        doc /* A handheld pendant control shall provide raise, lower, and stop buttons to operate the lift. */
        subject pendant : PendantControl;
        require pendant.buttonCount >= 3;
    }
    
    requirement CentralControlModule :> PatientLiftRequirements {
        doc /* A central control module shall process pendant commands and sensor inputs to control the actuator. */
        subject controller : ControlModule;
        require controller.maxSafeLoad > 0.0 [kg];
        require controller.maxHeight > controller.minHeight;
    }
    
    requirement PatientSlingReq :> PatientLiftRequirements {
        doc /* A detachable full-body patient sling made of polyester mesh shall attach to the lifting arm. */
        subject sling : PatientSling;
        require sling.material == "polyester mesh";
        require sling.isDetachable == true;
        require sling.maxLoad > 0.0 [kg];
    }
    
    requirement RechargeableBatteryReq :> PatientLiftRequirements {
        doc /* A rechargeable battery shall power the entire system. */
        subject battery : RechargeableBattery;
        require battery.nominalVoltage > 0.0 [V];
        require battery.capacity > 0.0 [C];
    }
    
    requirement LoadCellSafety :> PatientLiftRequirements {
        doc /* An integrated load cell shall continuously measure patient weight to prevent overloading. */
        subject loadCell : LoadCell;
        require loadCell.maxCapacity > 0.0 [kg];
        require loadCell.accuracy > 0.0 [kg];
    }
    
    requirement HeightSensorReq :> PatientLiftRequirements {
        doc /* A height sensor shall provide precise positioning feedback to the control system. */
        subject heightSensor : HeightSensor;
        require heightSensor.range > 0.0 [m];
        require heightSensor.resolution > 0.0 [m];
    }
    
    requirement EmergencyStopReq :> PatientLiftRequirements {
        doc /* A prominent emergency stop button shall immediately halt all movement when activated. */
        subject estopButton : EmergencyStopButton;
        require estopButton.location == "prominent";
    }
    
    requirement StateMachineReq :> PatientLiftRequirements {
        doc /* The system shall operate through standby, raising, lowering, and locked elevated states. */
        subject patientLift : PatientLift;
        require patientLift::LiftStates::standby.isDefined();
        require patientLift::LiftStates::raising.isDefined();
        require patientLift::LiftStates::lowering.isDefined();
        require patientLift::LiftStates::lockedElevated.isDefined();
    }
    
    requirement OverloadProtection :> PatientLiftRequirements {
        doc /* The system shall prevent lifting when the measured load exceeds the maximum safe load. */
        subject controller : ControlModule;
        require controller.maxSafeLoad <= loadCell.maxCapacity;
    }
    
    requirement SmoothControlledTransfer :> PatientLiftRequirements {
        doc /* The system shall ensure a smooth, controlled, and safe transfer process for patient and caregiver. */
        subject patientLift : PatientLift;
        require liftingArm.actuator.maxSpeed > 0.0 [m/s];
    }
}
