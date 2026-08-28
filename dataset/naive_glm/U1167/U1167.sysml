package PoweredExoskeleton {
    import ScalarValues::*;
    import ISQ::*;
    import ISQSpace::*;
    import ISQEnergy::*;
    import ISQElectricity::*;
    import ISQForce::*;
    import ISQTorque::*;
    import ISQTime::*;
    import ISQMass::*;
    import ISQAngle::*;
    import ISQVelocity::*;
    import ISQFrequency::*;

    // ===== Value Types =====
    value def TorqueValue :> Torque;
    value def ForceValue :> Force;
    value def AngleValue :> Angle;
    value def AngularVelocityValue :> AngularVelocity;
    value def VoltageValue :> ElectricPotential;
    value def CurrentValue :> ElectricCurrent;
    value def PowerValue :> Power;
    value def EnergyValue :> Energy;
    value def MassValue :> Mass;
    value def DurationValue :> Duration;
    value def FrequencyValue :> Frequency;
    value def Percentage :> Real;
    value def TemperatureValue :> ThermodynamicTemperature;

    // ===== Item Types =====
    item def ElectricalPower {
        attribute voltage : VoltageValue;
        attribute current : CurrentValue;
    }

    item def MotorCommand {
        attribute targetTorque : TorqueValue;
        attribute enabled : Boolean;
    }

    item def SensorReading {
        attribute jointId : String;
        attribute force : ForceValue;
        attribute angle : AngleValue;
        attribute angularVelocity : AngularVelocityValue;
        attribute timestamp : DurationValue;
    }

    item def UserIntent {
        attribute intendedTorque : TorqueValue;
        attribute movementDirection : String;
        attribute confidence : Percentage;
    }

    item def SystemStatus {
        attribute batteryLevel : Percentage;
        attribute jointHealth : String;
        attribute temperature : TemperatureValue;
        attribute faultDetected : Boolean;
    }

    item def SafetyAlert {
        attribute severity : Integer;
        attribute description : String;
        attribute sourceJoint : String;
    }

    // ===== Enumerations =====
    enum def OperationalMode {
        standby;
        active;
        emergency;
    }

    enum def JointType {
        hip;
        knee;
        ankle;
        shoulder;
        elbow;
        lumbar;
    }

    enum def FaultType {
        overTorque;
        overTemperature;
        lowBattery;
        sensorFailure;
        communicationLoss;
    }

    // ===== Port Definitions =====
    port def PowerPort {
        out item power : ElectricalPower;
    }

    port def CommandPort {
        out item command : MotorCommand;
    }

    port def SensorDataPort {
        out item reading : SensorReading;
    }

    port def StatusPort {
        out item status : SystemStatus;
    }

    port def AlertPort {
        out item alert : SafetyAlert;
    }

    // ===== Requirements =====
    requirement def AssistUserMovement {
        doc << "The exoskeleton shall amplify the user's natural movements during physically demanding tasks.">>
        attribute assistanceLevel : Percentage = 50;
        require satisfiedBy ::exoskeleton.assistanceFactor >= assistanceLevel;
    }

    requirement def StructuralIntegrity {
        doc <<"The frame shall be lightweight and strong, made from carbon fiber composite.">>
        attribute maxFrameMass : MassValue = 5.0 [kg];
        attribute loadCapacity : MassValue = 90.0 [kg];
        require satisfiedBy ::exoskeleton.frame.mass <= maxFrameMass;
    }

    requirement def SenseComputeActuateLatency {
        doc <<"The sense-compute-actuate cycle shall complete within 20 milliseconds.">>
        attribute maxLatency : DurationValue = 20.0 [ms];
        require satisfiedBy ::exoskeleton.controlProcessor.cycleLatency <= maxLatency;
    }

    requirement def BatteryEndurance {
        doc <<"The battery shall last for a full 6-hour work shift on a single charge.">>
        attribute minDuration : DurationValue = 6.0 [h];
        require satisfiedBy ::exoskeleton.batteryPack.nominalRuntime >= minDuration;
    }

    requirement def SafetyMonitoring {
        doc <<"The system shall continuously monitor battery level and joint states and transition to a safe state on fault detection.">>
        require satisfiedBy ::exoskeleton.safetyMonitor;
    }

    requirement def MultiModeOperation {
        doc <<"The system shall operate in standby, active, and emergency modes.">>
        require satisfiedBy ::exoskeleton.operationalMode;
    }

    // ===== Part Definitions =====

    part def StructuralFrame {
        attribute material : String = "CarbonFiberComposite";
        attribute mass : MassValue = 4.2 [kg];
        attribute loadCapacity : MassValue = 90.0 [kg];
        port in leftHipMount;
        port in rightHipMount;
        port in leftKneeMount;
        port in rightKneeMount;
        port in leftAnkleMount;
        port in rightAnkleMount;
        port in leftShoulderMount;
        port in rightShoulderMount;
        port in leftElbowMount;
        port in rightElbowMount;
        port in lumbarMount;
    }

    part def MotorActuator {
        attribute maxTorque : TorqueValue = 120.0 [N*m];
        attribute peakPower : PowerValue = 400.0 [W];
        attribute efficiency : Percentage = 85;
        port in powerInput : PowerPort;
        port in commandInput : CommandPort;
        port out torqueOutput;
        attribute currentTorque : TorqueValue = 0.0 [N*m];
        attribute temperature : TemperatureValue = 25.0 [degC];

        action def Actuate {
            in command : MotorCommand;
            out torque : TorqueValue;
            if command.enabled then {
                torque := command.targetTorque;
            } else {
                torque := 0.0 [N*m];
            }
        }
    }

    part def ForceSensor {
        attribute range : ForceValue = 500.0 [N];
        attribute resolution : ForceValue = 0.1 [N];
        port out sensorOutput : SensorDataPort;
        attribute measuredForce : ForceValue = 0.0 [N];

        action def MeasureForce {
            out force : ForceValue;
            force := measuredForce;
        }
    }

    part def AngleSensor {
        attribute range : AngleValue = 180.0 [deg];
        attribute resolution : AngleValue = 0.1 [deg];
        port out sensorOutput : SensorDataPort;
        attribute measuredAngle : AngleValue = 0.0 [deg];
        attribute measuredVelocity : AngularVelocityValue = 0.0 [deg/s];

        action def MeasureAngle {
            out angle : AngleValue;
            out velocity : AngularVelocityValue;
            angle := measuredAngle;
            velocity := measuredVelocity;
        }
    }

    part def JointModule {
        attribute jointType : JointType;
        attribute jointId : String;
        attribute maxRange : AngleValue = 120.0 [deg];
        attribute currentAngle : AngleValue = 0.0 [deg];
        attribute currentVelocity : AngularVelocityValue = 0.0 [deg/s];
        attribute appliedForce : ForceValue = 0.0 [N];
        attribute temperature : TemperatureValue = 25.0 [degC];
        attribute faultState : Boolean = false;

        port in powerInput : PowerPort;
        port in commandInput : CommandPort;
        port out sensorDataOutput : SensorDataPort;
        port out alertOutput : AlertPort;

        part motor : MotorActuator;
        part forceSensor : ForceSensor;
        part angleSensor : AngleSensor;

        connection powerToMotor connect powerInput to motor.powerInput;
        connection commandToMotor connect commandInput to motor.commandInput;

        action def Sense {
            out reading : SensorReading;
            reading.jointId := jointId;
            reading.force := forceSensor.measuredForce;
            reading.angle := angleSensor.measuredAngle;
            reading.angularVelocity := angleSensor.measuredVelocity;
            reading.timestamp := 0.0 [ms];
        }

        action def DetectFault {
            out alert : SafetyAlert;
            if motor.temperature > 70.0 [degC] then {
                alert.severity := 2;
                alert.description := "OverTemperature";
                alert.sourceJoint := jointId;
                faultState := true;
            }
            if motor.currentTorque > maxTorque then {
                alert.severity := 3;
                alert.description := "OverTorque";
                alert.sourceJoint := jointId;
                faultState := true;
            }
        }
    }

    part def ControlProcessor {
        attribute clockSpeed : FrequencyValue = 200.0 [MHz];
        attribute cycleLatency : DurationValue = 15.0 [ms];
        attribute assistanceLevel : Percentage = 50;
        attribute operationalMode : OperationalMode = OperationalMode::standby;

        port in sensorDataInputs : SensorDataPort[*];
        port out commandOutputs : CommandPort[*];
        port out statusOutput : StatusPort;
        port in alertInputs : AlertPort[*];

        attribute readings : SensorReading[*];
        attribute intents : UserIntent[*];
        attribute commands : MotorCommand[*];

        action def InterpretIntent {
            in reading : SensorReading;
            out intent : UserIntent;
            intent.intendedTorque := reading.force * 0.5 [m] * (assistanceLevel / 100.0);
            intent.movementDirection := "forward";
            intent.confidence := 80.0;
        }

        action def ComputeTorque {
            in intent : UserIntent;
            out command : MotorCommand;
            command.targetTorque := intent.intendedTorque;
            command.enabled := (operationalMode == OperationalMode::active);
        }

        action def SenseComputeActuate {
            in allReadings : SensorReading[*];
            out allCommands : MotorCommand[*];
            for r in allReadings {
                var intent : UserIntent;
                InterpretIntent(reading := r, intent := intent);
                var cmd : MotorCommand;
                ComputeTorque(intent := intent, command := cmd);
                allCommands := allCommands.append(cmd);
            }
        }

        state def ControlProcessorBehavior {
            entry; then Standby;

            state Standby {
                entry { operationalMode := OperationalMode::standby; }
                do SenseComputeActuate(allReadings := readings, allCommands := commands);
                transition Standby_to_Active
                    first Standby
                    if (readings.size > 0 and assistanceLevel > 0)
                    then Active;
            }

            state Active {
                entry { operationalMode := OperationalMode::active; }
                do SenseComputeActuate(allReadings := readings, allCommands := commands);
                transition Active_to_Emergency
                    first Active
                    if (alertInputs.size > 0)
                    then Emergency;
                transition Active_to_Standby
                    first Active
                    if (readings.size == 0)
                    then Standby;
            }

            state Emergency {
                entry { operationalMode := OperationalMode::emergency; }
                do {
                    for c in commands {
                        c.enabled := false;
                        c.targetTorque := 0.0 [N*m];
                    }
                }
                transition Emergency_to_Standby
                    first Emergency
                    if (alertInputs.size == 0)
                    then Standby;
            }
        }
    }

    part def BatteryPack {
        attribute nominalVoltage : VoltageValue = 48.0 [V];
        attribute capacity : EnergyValue = 500.0 [W*h];
        attribute nominalRuntime : DurationValue = 6.5 [h];
        attribute chargeLevel : Percentage = 100;
        attribute maxDischargeCurrent : CurrentValue = 60.0 [A];
        attribute cellChemistry : String = "LithiumIon";

        port out powerOutput : PowerPort;

        action def Discharge {
            in loadCurrent : CurrentValue;
            out remaining : Percentage;
            attribute elapsed : DurationValue = 0.0 [h];
            if loadCurrent > 0.0 [A] then {
                elapsed := elapsed + 0.001 [h];
                remaining := chargeLevel - (elapsed / nominalRuntime) * 100.0;
            }
        }

        action def Charge {
            in chargeCurrent : CurrentValue;
            out remaining : Percentage;
            if chargeCurrent > 0.0 [A] then {
                remaining := chargeLevel + 10.0;
            }
        }

        state def BatteryBehavior {
            entry; then Charging;

            state Charging {
                do Charge(chargeCurrent := 10.0 [A], remaining := chargeLevel);
                transition Charging_to_Full
                    first Charging
                    if (chargeLevel >= 100)
                    then Full;
            }

            state Full {
                transition Full_to_Discharging
                    first Full
                    if (powerOutput.isConnected)
                    then Discharging;
            }

            state Discharging {
                do Discharge(loadCurrent := 30.0 [A], remaining := chargeLevel);
                transition Discharging_to_Low
                    first Discharging
                    if (chargeLevel <= 20)
                    then Low;
            }

            state Low {
                transition Low_to_Critical
                    first Low
                    if (chargeLevel <= 5)
                    then Critical;
            }

            state Critical {
                // Emit low battery alert
            }
        }
    }

    part def SafetyMonitor {
        attribute monitoringInterval : DurationValue = 10.0 [ms];
        attribute faultThreshold : TemperatureValue = 70.0 [degC];
        attribute minBatteryLevel : Percentage = 10;

        port in statusInput : StatusPort;
        port in alertInputs : AlertPort[*];
        port out alertOutput : AlertPort;

        action def Monitor {
            in status : SystemStatus;
            out alert : SafetyAlert;
            if status.batteryLevel < minBatteryLevel then {
                alert.severity := 3;
                alert.description := "LowBattery";
                alert.sourceJoint := "system";
            }
            if status.temperature > faultThreshold then {
                alert.severity := 2;
                alert.description := "OverTemperature";
                alert.sourceJoint := "system";
            }
            if status.faultDetected then {
                alert.severity := 3;
                alert.description := "JointFault";
                alert.sourceJoint := "system";
            }
        }
    }

    part def UserInterface {
        attribute assistanceLevelSetting : Percentage = 50;
        attribute displayMode : OperationalMode = OperationalMode::standby;
        port out statusDisplay : StatusPort;
        port in statusInput : StatusPort;
    }

    // ===== Top-Level Exoskeleton System =====
    part def PoweredExoskeletonSystem {
        attribute assistanceFactor : Percentage = 50;
        attribute operationalMode : OperationalMode = OperationalMode::standby;

        satisfy AssistUserMovement;
        satisfy StructuralIntegrity;
        satisfy SenseComputeActuateLatency;
        satisfy BatteryEndurance;
        satisfy SafetyMonitoring;
        satisfy MultiModeOperation;

        part frame : StructuralFrame;

        part leftHip : JointModule { :>> jointType = JointType::hip; :>> jointId = "leftHip"; }
        part rightHip : JointModule { :>> jointType = JointType::hip; :>> jointId = "rightHip"; }
        part leftKnee : JointModule { :>> jointType = JointType::knee; :>> jointId = "leftKnee"; }
        part rightKnee : JointModule { :>> jointType = JointType::knee; :>> jointId = "rightKnee"; }
        part leftAnkle : JointModule { :>> jointType = JointType::ankle; :>> jointId = "leftAnkle"; }
        part rightAnkle : JointModule { :>> jointType = JointType::ankle; :>> jointId = "rightAnkle"; }
        part leftShoulder : JointModule { :>> jointType = JointType::shoulder; :>> jointId = "leftShoulder"; }
        part rightShoulder : JointModule { :>> jointType = JointType::shoulder; :>> jointId = "rightShoulder"; }
        part leftElbow : JointModule { :>> jointType = JointType::elbow; :>> jointId = "leftElbow"; }
        part rightElbow : JointModule { :>> jointType = JointType::elbow; :>> jointId = "rightElbow"; }
        part lumbar : JointModule { :>> jointType = JointType::lumbar; :>> jointId = "lumbar"; }

        part controlProcessor : ControlProcessor;
        part batteryPack : BatteryPack;
        part safetyMonitor : SafetyMonitor;
        part userInterface : UserInterface;

        // Power distribution from battery to all joints and processor
        connection batteryToProcessorPower connect batteryPack.powerOutput to controlProcessor;
        connection batteryToLeftHipPower connect batteryPack.powerOutput to leftHip.powerInput;
        connection batteryToRightHipPower connect batteryPack.powerOutput to rightHip.powerInput;
        connection batteryToLeftKneePower connect batteryPack.powerOutput to leftKnee.powerInput;
        connection batteryToRightKneePower connect batteryPack.powerOutput to rightKnee.powerInput;
        connection batteryToLeftAnklePower connect batteryPack.powerOutput to leftAnkle.powerInput;
        connection batteryToRightAnklePower connect batteryPack.powerOutput to rightAnkle.powerInput;
        connection batteryToLeftShoulderPower connect batteryPack.powerOutput to leftShoulder.powerInput;
        connection batteryToRightShoulderPower connect batteryPack.powerOutput to rightShoulder.powerInput;
        connection batteryToLeftElbowPower connect batteryPack.powerOutput to leftElbow.powerInput;
        connection batteryToRightElbowPower connect batteryPack.powerOutput to rightElbow.powerInput;
        connection batteryToLumbarPower connect batteryPack.powerOutput to lumbar.powerInput;

        // Sensor data from joints to control processor
        connection leftHipSensorToProcessor connect leftHip.sensorDataOutput to controlProcessor.sensorDataInputs;
        connection rightHipSensorToProcessor connect rightHip.sensorDataOutput to controlProcessor.sensorDataInputs;
        connection leftKneeSensorToProcessor connect leftKnee.sensorDataOutput to controlProcessor.sensorDataInputs;
        connection rightKneeSensorToProcessor connect rightKnee.sensorDataOutput to controlProcessor.sensorDataInputs;
        connection leftAnkleSensorToProcessor connect leftAnkle.sensorDataOutput to controlProcessor.sensorDataInputs;
        connection rightAnkleSensorToProcessor connect rightAnkle.sensorDataOutput to controlProcessor.sensorDataInputs;
        connection leftShoulderSensorToProcessor connect leftShoulder.sensorDataOutput to controlProcessor.sensorDataInputs;
        connection rightShoulderSensorToProcessor connect rightShoulder.sensorDataOutput to controlProcessor.sensorDataInputs;
        connection leftElbowSensorToProcessor connect leftElbow.sensorDataOutput to controlProcessor.sensorDataInputs;
        connection rightElbowSensorToProcessor connect rightElbow.sensorDataOutput to controlProcessor.sensorDataInputs;
        connection lumbarSensorToProcessor connect lumbar.sensorDataOutput to controlProcessor.sensorDataInputs;

        // Commands from processor to joints
        connection processorToLeftHipCommand connect controlProcessor.commandOutputs to leftHip.commandInput;
        connection processorToRightHipCommand connect controlProcessor.commandOutputs to rightHip.commandInput;
        connection processorToLeftKneeCommand connect controlProcessor.commandOutputs to leftKnee.commandInput;
        connection processorToRightKneeCommand connect controlProcessor.commandOutputs to rightKnee.commandInput;
        connection processorToLeftAnkleCommand connect controlProcessor.commandOutputs to leftAnkle.commandInput;
        connection processorToRightAnkleCommand connect controlProcessor.commandOutputs to rightAnkle.commandInput;
        connection processorToLeftShoulderCommand connect controlProcessor.commandOutputs to leftShoulder.commandInput;
        connection processorToRightShoulderCommand connect controlProcessor.commandOutputs to rightShoulder.commandInput;
        connection processorToLeftElbowCommand connect controlProcessor.commandOutputs to leftElbow.commandInput;
        connection processorToRightElbowCommand connect controlProcessor.commandOutputs to rightElbow.commandInput;
        connection processorToLumbarCommand connect controlProcessor.commandOutputs to lumbar.commandInput;

        // Alerts from joints to safety monitor
        connection leftHipAlertToMonitor connect leftHip.alertOutput to safetyMonitor.alertInputs;
        connection rightHipAlertToMonitor connect rightHip.alertOutput to safetyMonitor.alertInputs;
        connection leftKneeAlertToMonitor connect leftKnee.alertOutput to safetyMonitor.alertInputs;
        connection rightKneeAlertToMonitor connect rightKnee.alertOutput to safetyMonitor.alertInputs;
        connection leftAnkleAlertToMonitor connect leftAnkle.alertOutput to safetyMonitor.alertInputs;
        connection rightAnkleAlertToMonitor connect rightAnkle.alertOutput to safetyMonitor.alertInputs;
        connection leftShoulderAlertToMonitor connect leftShoulder.alertOutput to safetyMonitor.alertInputs;
        connection rightShoulderAlertToMonitor connect rightShoulder.alertOutput to safetyMonitor.alertInputs;
        connection leftElbowAlertToMonitor connect leftElbow.alertOutput to safetyMonitor.alertInputs;
        connection rightElbowAlertToMonitor connect rightElbow.alertOutput to safetyMonitor.alertInputs;
        connection lumbarAlertToMonitor connect lumbar.alertOutput to safetyMonitor.alertInputs;

        // Alerts from safety monitor to control processor
        connection monitorToProcessorAlert connect safetyMonitor.alertOutput to controlProcessor.alertInputs;

        // Status from processor to user interface
        connection processorToUIStatus connect controlProcessor.statusOutput to userInterface.statusInput;

        // System-level state machine
        state def ExoskeletonOperation {
            entry; then StandbyMode;

            state StandbyMode {
                entry { operationalMode := OperationalMode::standby; }
                do { controlProcessor.operationalMode := OperationalMode::standby; }
                transition Standby_to_Active
                    first StandbyMode
                    if (userInterface.assistanceLevelSetting > 0 and batteryPack.chargeLevel > 10)
                    then ActiveMode;
            }

            state ActiveMode {
                entry { operationalMode := OperationalMode::active; }
                do { controlProcessor.operationalMode := OperationalMode::active; }
                transition Active_to_Emergency
                    first ActiveMode
                    if (safetyMonitor.alertOutput.alert.severity >= 2)
                    then EmergencyMode;
                transition Active_to_Standby
                    first ActiveMode
                    if (userInterface.assistanceLevelSetting == 0)
                    then StandbyMode;
            }

            state EmergencyMode {
                entry { operationalMode := OperationalMode::emergency; }
                do {
                    controlProcessor.operationalMode := OperationalMode::emergency;
                    for j in {leftHip, rightHip, leftKnee, rightKnee, leftAnkle, rightAnkle,
                              leftShoulder, rightShoulder, leftElbow, rightElbow, lumbar} {
                        j.motor.currentTorque := 0.0 [N*m];
                    }
                }
                transition Emergency_to_Standby
                    first EmergencyMode
                    if (safetyMonitor.alertOutput.alert.severity == 0)
                    then StandbyMode;
            }
        }
    }

    // ===== Instance =====
    part exoskeleton : PoweredExoskeletonSystem {
        :>> assistanceFactor = 50;
    }
}
