package PantographPowerCollectionSystem {

    import ScalarValues::*;
    import ScalarFunctions::*;

    // ============ VALUE TYPES ============

    value def Voltage :> Real { doc "Electric potential in volts (V)"; }
    value def Current :> Real { doc "Electric current in amperes (A)"; }
    value def Force :> Real { doc "Mechanical force in newtons (N)"; }
    value def Pressure :> Real { doc "Pneumatic pressure in pascals (Pa)"; }
    value def Length :> Real { doc "Linear dimension in meters (m)"; }
    value def Angle :> Real { doc "Angular dimension in radians (rad)"; }
    value def Mass :> Real { doc "Mass in kilograms (kg)"; }
    value def Duration :> Real { doc "Time duration in seconds (s)"; }
    value def WearDepth :> Real { doc "Material wear depth in millimeters (mm)"; }
    value def Speed :> Real { doc "Linear speed in meters per second (m/s)"; }
    value def Temperature :> Real { doc "Temperature in degrees Celsius (degC)"; }
    value def Frequency :> Real { doc "Frequency in hertz (Hz)"; }
    value def Power :> Real { doc "Electric power in watts (W)"; }

    // ============ ITEM TYPES ============

    item def ElectricPower {
        attribute voltage : Voltage;
        attribute current : Current;
    }

    item def HighVoltageACPower :> ElectricPower {
        attribute :>> voltage : Voltage = 25000;
        attribute frequency : Frequency = 50;
    }

    item def CompressedAir {
        attribute pressure : Pressure;
    }

    item def ControlCommand {
        attribute commandType : String;
        attribute parameterValue : Real;
    }

    item def ForceReading {
        attribute force : Force;
    }

    item def WearReading {
        attribute wearDepth : WearDepth;
    }

    item def HeightReading {
        attribute height : Length;
    }

    // ============ PORT DEFINITIONS ============

    port def ElectricPowerPort {
        out item power : ElectricPower;
    }

    port def HVPowerPort :> ElectricPowerPort {
        redefines power : HighVoltageACPower;
    }

    port def PneumaticPort {
        out item air : CompressedAir;
    }

    port def ControlPort {
        in item command : ControlCommand;
        out item feedback : ForceReading;
    }

    port def MechanicalMountPort;

    port def WireContactPort {
        out item collectedPower : HighVoltageACPower;
        in item contactForce : ForceReading;
    }

    port def WearMonitorPort {
        out item wearData : WearReading;
    }

    port def ForceSensorPort {
        out item reading : ForceReading;
    }

    port def HeightSensorPort {
        out item reading : HeightReading;
    }

    // ============ REQUIREMENTS ============

    requirement def MaintainContactForce {
        doc /* The pantograph shall maintain a nominal contact force between 70 and 120 N against the overhead wire, preventing both poor connection and excessive wear. */;
        attribute minForce : Force = 70;
        attribute maxForce : Force = 120;
        attribute measuredForce : Force;
        requirement constraint { minForce <= measuredForce and measuredForce <= maxForce }
    }

    requirement def CollectHighVoltagePower {
        doc /* The pantograph shall collect 25,000 V AC power from the overhead wire to run traction motors and onboard systems. */;
        attribute nominalVoltage : Voltage = 25000;
        attribute voltageTolerance : Voltage = 1000;
        attribute measuredVoltage : Voltage;
        requirement constraint {
            (nominalVoltage - voltageTolerance) <= measuredVoltage and
            measuredVoltage <= (nominalVoltage + voltageTolerance)
        }
    }

    requirement def ProvideElectricalInsulation {
        doc /* The insulator shall prevent high-voltage electricity from passing into the body of the vehicle, protecting equipment and passengers. */;
        attribute dielectricRating : Voltage = 40000;
        attribute maxLeakageCurrent : Current = 0.001;
        attribute measuredLeakage : Current;
        requirement constraint { measuredLeakage <= maxLeakageCurrent }
    }

    requirement def SupportEmergencyLowering {
        doc /* The pantograph shall include an emergency lowering function for rapid, safe retraction. */;
        attribute maxLoweringTime : Duration = 3;
        attribute actualLoweringTime : Duration;
        requirement constraint { actualLoweringTime <= maxLoweringTime }
    }

    requirement def MaintainContinuousContact {
        doc /* The pantograph shall establish and maintain a continuous electrical connection with the overhead power wire. */;
        attribute maxContactLossDuration : Duration = 0.5;
        attribute contactLossDuration : Duration;
        requirement constraint { contactLossDuration <= maxContactLossDuration }
    }

    requirement def ActiveHeightAdjustment {
        doc /* The system shall actively adjust its height to maintain nominal contact force as the overhead wire height varies. */;
        attribute adjustmentResponseTime : Duration = 0.1;
        attribute actualResponseTime : Duration;
        requirement constraint { actualResponseTime <= adjustmentResponseTime }
    }

    // ============ PART DEFINITIONS: COMPONENTS ============

    part def CarbonContactStrip {
        attribute width : Length = 0.04;
        attribute maxWearDepth : WearDepth = 5;
        attribute currentWearDepth : WearDepth = 0;
        attribute material : String = "carbon graphite";
        attribute conductivityRating : Current = 1000;
        attribute maxOperatingTemp : Temperature = 150;

        port wearMonitor : WearMonitorPort;
        port electricalContact : ElectricPowerPort;
        port mechanicalMount : MechanicalMountPort;

        action def MonitorWear {
            out wearLevel : WearDepth;
        }

        action def TransmitPower {
            in inputPower : HighVoltageACPower;
            out outputPower : HighVoltageACPower;
        }
    }

    part def CollectorHead {
        attribute numberOfStrips : Integer = 2;
        attribute hornAngle : Angle = 0.2618;
        attribute headMass : Mass = 3.5;
        attribute maxTiltAngle : Angle = 0.1745;

        part contactStrips [2] : CarbonContactStrip;

        port wireContact : WireContactPort;
        port mechanicalBase : MechanicalMountPort;

        connection stripsToWire connects contactStrips.electricalContact to wireContact;

        action def AdjustHeadAngle {
            in targetAngle : Angle;
            out actualAngle : Angle;
        }

        action def DistributeCurrent {
            in totalCurrent : Current;
            out perStripCurrent : Current;
        }
    }

    part def UpperArm {
        attribute length : Length = 1.2;
        attribute mass : Mass = 8.5;
        attribute currentAngle : Angle = 0;
        attribute maxAngle : Angle = 2.0944;
        attribute minAngle : Angle = 0;

        port lowerJoint : MechanicalMountPort;
        port upperJoint : MechanicalMountPort;

        action def Rotate {
            in targetAngle : Angle;
            out achievedAngle : Angle;
        }
    }

    part def LowerArm {
        attribute length : Length = 1.0;
        attribute mass : Mass = 12.0;
        attribute currentAngle : Angle = 0;
        attribute maxAngle : Angle = 1.5708;
        attribute minAngle : Angle = 0;

        port baseJoint : MechanicalMountPort;
        port upperJoint : MechanicalMountPort;

        action def Rotate {
            in targetAngle : Angle;
            out achievedAngle : Angle;
        }
    }

    part def ArticulatedArmStructure {
        attribute maxHeight : Length = 2.5;
        attribute minHeight : Length = 0.3;
        attribute currentHeight : Length = 0.3;
        attribute raisedHeight : Length = 2.0;
        attribute stowedHeight : Length = 0.3;

        part lowerArm : LowerArm;
        part upperArm : UpperArm;
        part collectorHead : CollectorHead;

        port forceSensor : ForceSensorPort;
        port heightSensor : HeightSensorPort;
        port baseMount : MechanicalMountPort;

        connection lowerToUpper connects lowerArm::upperJoint to upperArm::lowerJoint;
        connection upperToHead connects upperArm::upperJoint to collectorHead::mechanicalBase;
        connection baseToArm connects baseMount to lowerArm::baseJoint;

        action def Raise {
            in targetHeight : Length;
            out achievedHeight : Length;
        }

        action def Lower {
            in targetHeight : Length;
            out achievedHeight : Length;
        }

        action def AdjustHeight {
            in targetForce : Force;
            in wireHeight : Length;
            out achievedHeight : Length;
            out achievedForce : Force;
        }

        action def MeasureForce {
            out forceReading : ForceReading;
        }

        action def MeasureHeight {
            out heightReading : HeightReading;
        }
    }

    part def SpringAssembly {
        attribute springConstant : Real = 5000;
        attribute nominalCompression : Length = 0.015;
        attribute currentCompression : Length = 0.015;
        attribute targetUpwardForce : Force = 90;
        attribute maxCompression : Length = 0.03;
        attribute minCompression : Length = 0.005;

        port mechanicalOutput : MechanicalMountPort;
        port mechanicalInput : MechanicalMountPort;

        action def ApplyUpwardForce {
            in compression : Length;
            out appliedForce : Force;
        }

        action def AdjustCompression {
            in targetForce : Force;
            out adjustedCompression : Length;
        }
    }

    part def PneumaticActuator {
        attribute maxPressure : Pressure = 800000;
        attribute operatingPressure : Pressure = 600000;
        attribute pistonDiameter : Length = 0.06;
        attribute strokeLength : Length = 0.2;
        attribute currentPressure : Pressure = 0;
        attribute emergencyVentRate : Real = 0.5;

        port airInput : PneumaticPort;
        port mechanicalOutput : MechanicalMountPort;

        action def Extend {
            in airPressure : Pressure;
            out extensionForce : Force;
        }

        action def Retract {
            in airPressure : Pressure;
            out retractionForce : Force;
        }

        action def EmergencyVent {
            out ventedPressure : Pressure;
        }

        action def HoldPosition {
            in holdPressure : Pressure;
        }
    }

    part def Insulator {
        attribute height : Length = 0.25;
        attribute diameter : Length = 0.15;
        attribute dielectricStrength : Voltage = 40000;
        attribute creepageDistance : Length = 0.8;
        attribute material : String = "porcelain composite";
        attribute maxLeakageCurrent : Current = 0.001;

        port roofMount : MechanicalMountPort;
        port pantographMount : MechanicalMountPort;
        port hvPassThrough : HVPowerPort;
        port vehicleBusConnection : ElectricPowerPort;

        satisfy ProvideElectricalInsulation {
            attribute measuredLeakage = maxLeakageCurrent;
        }

        action def Insulate {
            in appliedVoltage : Voltage;
            out leakageCurrent : Current;
        }

        action def ConductPower {
            in inputPower : HighVoltageACPower;
            out outputPower : ElectricPower;
        }
    }

    part def PantographController {
        attribute samplingRate : Real = 100;
        attribute targetForce : Force = 90;
        attribute minForceThreshold : Force = 70;
        attribute maxForceThreshold : Force = 120;
        attribute emergencyLowerActive : Boolean = false;
        attribute contactLossThreshold : Duration = 0.5;
        attribute proportionalGain : Real = 0.5;
        attribute integralGain : Real = 0.1;

        port controlInput : ControlPort;
        port actuatorOutput : PneumaticPort;
        port forceInput : ~ForceSensorPort;
        port heightInput : ~HeightSensorPort;
        port wearInput : ~WearMonitorPort;

        action def MonitorContactForce {
            in forceReading : Force;
            out adjustmentNeeded : Boolean;
            out adjustmentValue : Pressure;
        }

        action def TriggerEmergencyLower {
            out emergencyCommand : ControlCommand;
        }

        action def RegulatePressure {
            in targetForce : Force;
            in measuredForce : Force;
            out regulatedPressure : Pressure;
        }

        action def DetectContactLoss {
            in forceReading : Force;
            out contactLost : Boolean;
        }

        action def MonitorWearLevel {
            in wearData : WearReading;
            out replacementNeeded : Boolean;
        }
    }

    // ============ MAIN PANTOGRAPH PART ============

    part def Pantograph {
        attribute nominalVoltage : Voltage = 25000;
        attribute maxOperatingSpeed : Speed = 55.56;
        attribute currentContactForce : Force = 0;
        attribute currentHeight : Length = 0.3;
        attribute isCollectingPower : Boolean = false;
        attribute systemStatus : String = "stowed";

        part insulator : Insulator;
        part armStructure : ArticulatedArmStructure;
        part springAssembly : SpringAssembly;
        part pneumaticActuator : PneumaticActuator;
        part controller : PantographController;

        port roofMountInterface : MechanicalMountPort;
        port vehicleBusPort : ElectricPowerPort;
        port wireContactPort : WireContactPort;
        port controlInterface : ControlPort;
        port pneumaticSupply : PneumaticPort;

        connection roofToInsulator connects roofMountInterface to insulator.roofMount;
        connection insulatorToArm connects insulator.pantographMount to armStructure.baseMount;
        connection actuatorToArm connects pneumaticActuator.mechanicalOutput to armStructure.baseMount;
        connection springToArm connects springAssembly.mechanicalOutput to armStructure.baseMount;
        connection controllerToActuator connects controller.actuatorOutput to pneumaticActuator.airInput;
        connection armToInsulator connects armStructure.collectorHead.wireContact to insulator.hvPassThrough;
        connection insulatorToBus connects insulator.vehicleBusConnection to vehicleBusPort;
        connection wireToArm connects wireContactPort to armStructure.collectorHead.wireContact;
        connection controlToController connects controlInterface to controller.controlInput;
        connection pneumaticToActuator connects pneumaticSupply to pneumaticActuator.airInput;
        connection forceSensorToController connects armStructure.forceSensor to controller.forceInput;
        connection heightSensorToController connects armStructure.heightSensor to controller.heightInput;
        connection wearToController connects armStructure.collectorHead.contactStrips.wearMonitor to controller.wearInput;

        satisfy MaintainContactForce {
            attribute measuredForce = currentContactForce;
        }
        satisfy CollectHighVoltagePower {
            attribute measuredVoltage = nominalVoltage;
        }
        satisfy SupportEmergencyLowering;
        satisfy MaintainContinuousContact;
        satisfy ActiveHeightAdjustment;

        // ---- State Machine ----

        state def PantographStates {
            entry action initializeSystem;

            state stowed {
                doc /* Pantograph is safely stowed in lowered position. */;
                entry action confirmStowed;
                do action holdStowed;
                transition to raising
                    when controlInterface.command.commandType == "RAISE";
            }

            state raising {
                doc /* Pantograph is in the process of raising into contact position. */;
                entry action startRaiseSequence;
                do action raiseAction : ArticulatedArmStructure::Raise;
                do action regulateAction : PantographController::RegulatePressure;
                transition to operational
                    when armStructure.currentHeight >= armStructure.raisedHeight
                    and currentContactForce >= 70;
                transition to fault
                    when currentContactForce < 10
                    after 5;
            }

            state operational {
                doc /* Pantograph is fully operational and collecting power. */;
                entry action engagePowerCollection;
                do action adjustAction : ArticulatedArmStructure::AdjustHeight;
                do action regulateAction : PantographController::RegulatePressure;
                do action monitorForce : PantographController::MonitorContactForce;
                do action detectLoss : PantographController::DetectContactLoss;
                transition to lowering
                    when controlInterface.command.commandType == "LOWER";
                transition to fault
                    when currentContactForce < 10;
                transition to emergencyLowering
                    when controller.emergencyLowerActive == true;
            }

            state lowering {
                doc /* Pantograph is in the process of lowering to stowed position. */;
                entry action startLowerSequence;
                do action lowerAction : ArticulatedArmStructure::Lower;
                transition to stowed
                    when armStructure.currentHeight <= armStructure.minHeight;
            }

            state emergencyLowering {
                doc /* Emergency rapid retraction of pantograph. */;
                entry action triggerEmergencyLower;
                do action emergencyVentAction : PneumaticActuator::EmergencyVent;
                do action emergencyLowerAction : ArticulatedArmStructure::Lower;
                transition to stowed
                    when armStructure.currentHeight <= armStructure.minHeight;
            }

            state fault {
                doc /* Pantograph has lost contact or detected a fault condition. */;
                entry action logFault;
                do action attemptRecovery;
                transition to stowed
                    when controlInterface.command.commandType == "RESET";
                transition to emergencyLowering
                    when controlInterface.command.commandType == "EMERGENCY_LOWER";
            }
        }

        state machine : PantographStates;

        // ---- Actions ----

        action def RaisePantograph {
            in targetHeight : Length;
            out achievedHeight : Length;
        }

        action def LowerPantograph {
            in targetHeight : Length;
            out achievedHeight : Length;
        }

        action def EmergencyLower {
            out loweringTime : Duration;
        }

        action def CollectPower {
            in wireVoltage : Voltage;
            out collectedPower : HighVoltageACPower;
        }

        action def MonitorSystem {
            out forceReading : Force;
            out heightReading : Length;
            out wearReading : WearDepth;
        }
    }

    // ============ EXTERNAL SYSTEM PARTS ============

    part def OverheadCatenaryWire {
        attribute wireVoltage : Voltage = 25000;
        attribute nominalHeight : Length = 5.5;
        attribute heightVariation : Length = 0.3;
        attribute wireMaterial : String = "copper alloy";
        attribute wireDiameter : Length = 0.012;
        attribute currentHeight : Length = 5.5;

        port wireInterface : WireContactPort;

        action def VaryHeight {
            out currentHeight : Length;
        }

        action def SupplyPower {
            out suppliedPower : HighVoltageACPower;
        }
    }

    part def VehiclePowerBus {
        attribute busVoltage : Voltage = 25000;
        attribute busCurrent : Current = 0;
        attribute maxCurrent : Current = 800;

        port busInput : ElectricPowerPort;
        port tractionMotorFeed : ElectricPowerPort;
        port auxiliaryFeed : ElectricPowerPort;

        action def DistributePower {
            in inputPower : ElectricPower;
            out tractionPower : ElectricPower;
            out auxiliaryPower : ElectricPower;
        }
    }

    part def TractionMotor {
        attribute ratedVoltage : Voltage = 25000;
        attribute ratedPower : Power = 500000;
        attribute currentSpeed : Speed = 0;
        attribute efficiency : Real = 0.92;

        port powerInput : ElectricPowerPort;

        action def DriveVehicle {
            in inputPower : ElectricPower;
            out vehicleSpeed : Speed;
        }
    }

    part def AuxiliarySystems {
        attribute ratedVoltage : Voltage = 25000;
        attribute totalLoad : Power = 50000;
        attribute lightingLoad : Power = 10000;
        attribute hvacLoad : Power = 30000;
        attribute controlLoad : Power = 10000;

        port powerInput : ElectricPowerPort;

        action def OperateSystems {
            in inputPower : ElectricPower;
        }
    }

    part def PneumaticSupplySystem {
        attribute tankPressure : Pressure = 900000;
        attribute minPressure : Pressure = 500000;
        attribute tankVolume : Real = 0.05;

        port airOutput : PneumaticPort;

        action def SupplyCompressedAir {
            out suppliedAir : CompressedAir;
        }
    }

    part def VehicleControlSystem {
        attribute vehicleSpeed : Speed = 0;
        attribute driverCommand : String = "NONE";

        port pantographControl : ControlPort;
        port pneumaticControl;

        action def IssueCommands {
            out raiseCommand : ControlCommand;
            out lowerCommand : ControlCommand;
            out emergencyCommand : ControlCommand;
        }

        action def MonitorPantographStatus {
            in forceFeedback : ForceReading;
            out statusUpdate : String;
        }
    }

    // ============ TOP-LEVEL VEHICLE ============

    part def ElectricRailVehicle {
        attribute vehicleType : String = "electric train";
        attribute maxSpeed : Speed = 55.56;
        attribute currentSpeed : Speed = 0;
        attribute numberOfPantographs : Integer = 1;

        part pantograph : Pantograph;
        part overheadWire : OverheadCatenaryWire;
        part powerBus : VehiclePowerBus;
        part tractionMotors [4] : TractionMotor;
        part auxiliarySystems : AuxiliarySystems;
        part pneumaticSupply : PneumaticSupplySystem;
        part vehicleController : VehicleControlSystem;

        connection wireToPantograph connects overheadWire.wireInterface to pantograph.wireContactPort;
        connection pantographToBus connects pantograph.vehicleBusPort to powerBus.busInput;
        connection busToTraction connects powerBus.tractionMotorFeed to tractionMotors.powerInput;
        connection busToAuxiliary connects powerBus.auxiliaryFeed to auxiliarySystems.powerInput;
        connection pneumaticToPantograph connects pneumaticSupply.airOutput to pantograph.pneumaticSupply;
        connection controllerToPantograph connects vehicleController.pantographControl to pantograph.controlInterface;
        connection pantographRoofMount connects pantograph.roofMountInterface to roofMountInterface;

        port roofMountInterface : MechanicalMountPort;

        satisfy CollectHighVoltagePower by pantograph;
        satisfy MaintainContactForce by pantograph;
        satisfy ProvideElectricalInsulation by pantograph.insulator;
        satisfy SupportEmergencyLowering by pantograph;
        satisfy MaintainContinuousContact by pantograph;
        satisfy ActiveHeightAdjustment by pantograph;

        action def OperateVehicle {
            in driverInput : String;
            out vehicleSpeed : Speed;
        }

        action def StartPowerCollection {
            out powerStatus : Boolean;
        }

        action def StopPowerCollection {
            out powerStatus : Boolean;
        }
    }
}
