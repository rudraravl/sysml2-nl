package SupportSurfaceModel {
    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Pressure;
    attribute def Force;
    attribute def Area;
    attribute def Temperature;
    attribute def Mass;
    attribute def Time;
    attribute def Length;
    attribute def Power;
    attribute def Ratio;

    item def SupportedLoad {
        attribute mass : Mass;
        attribute contactArea : Area;
        attribute centerOfMassX : Length;
        attribute centerOfMassY : Length;
    }

    item def BodyPressureMap {
        attribute peakPressure : Pressure;
        attribute averagePressure : Pressure;
        attribute leftZonePressure : Pressure;
        attribute centerZonePressure : Pressure;
        attribute rightZonePressure : Pressure;
    }

    item def SupportCommand {
        attribute targetMode : SupportMode;
        attribute targetFirmness : Ratio;
        attribute targetHeight : Length;
    }

    item def SupportStatus {
        attribute currentMode : SupportMode;
        attribute surfaceReady : Boolean;
        attribute peakPressure : Pressure;
        attribute averageFirmness : Ratio;
        attribute faultPresent : Boolean;
    }

    enum def SupportMode {
        enum rest;
        enum loadDistribution;
        enum stabilization;
        enum transferAssist;
        enum faultSafe;
    }

    port def MechanicalLoadPort {
        in item load : SupportedLoad;
        out item reactionPressure : BodyPressureMap;
    }

    port def CommandPort {
        in item command : SupportCommand;
    }

    port def StatusPort {
        out item status : SupportStatus;
    }

    port def PowerPort {
        in attribute supplyVoltage : Real;
        in attribute availablePower : Power;
    }

    port def AirFlowPort {
        out attribute flowRate : Real;
        out attribute pressure : Pressure;
    }

    part def SupportSurfaceSystem {
        attribute totalLength : Length = 2.00 [m];
        attribute totalWidth : Length = 0.90 [m];
        attribute nominalThickness : Length = 0.18 [m];
        attribute maximumSupportedMass : Mass = 180 [kg];
        attribute maximumAllowablePeakPressure : Pressure = 4.00 [kPa];
        attribute minimumStableContactArea : Area = 0.35 [m^2];

        port loadInterface : MechanicalLoadPort;
        port commandInterface : CommandPort;
        port statusInterface : StatusPort;
        port electricalInterface : PowerPort;

        part supportCore : LayeredSupportCore;
        part sensorArray : PressureSensorArray;
        part actuatorArray : PneumaticActuatorArray;
        part controller : SurfaceController;
        part cover : DurableCover;
        part frame : PerimeterFrame;

        connection loadToCore connect loadInterface to supportCore.loadPort;
        connection coreToSensors connect supportCore.sensorPort to sensorArray.pressureInput;
        connection controllerToActuators connect controller.airControlOutput to actuatorArray.controlInput;
        connection actuatorsToCore connect actuatorArray.airOutput to supportCore.actuationInput;
        connection sensorsToController connect sensorArray.pressureMapOutput to controller.pressureMapInput;
        connection commandToController connect commandInterface to controller.commandInput;
        connection controllerToStatus connect controller.statusOutput to statusInterface;
        connection powerToController connect electricalInterface to controller.powerInput;

        action distributeLoad {
            in item incomingLoad : SupportedLoad;
            out item pressureMap : BodyPressureMap;

            first start;
            then senseLoad;
            then computePressureProfile;
            then adjustSupportZones;
            then verifyPeakPressure;
            then done;

            action senseLoad {
                in item incomingLoad : SupportedLoad;
                out item measuredPressure : BodyPressureMap;
            }

            action computePressureProfile {
                in item measuredPressure : BodyPressureMap;
                out item desiredZoneFirmness : SupportCommand;
            }

            action adjustSupportZones {
                in item desiredZoneFirmness : SupportCommand;
                out item adjustedPressure : BodyPressureMap;
            }

            action verifyPeakPressure {
                in item adjustedPressure : BodyPressureMap;
                out item pressureMap : BodyPressureMap;
            }
        }

        state usageState {
            state unpowered;
            state initializing;
            state ready;
            state supporting;
            state assistingTransfer;
            state faultSafe;

            entry action unpowered {
                controller.disableActuation;
            }

            transition unpowered_to_initializing
                first unpowered
                accept PowerAvailable
                then initializing;

            transition initializing_to_ready
                first initializing
                accept SelfTestPassed
                then ready;

            transition ready_to_supporting
                first ready
                accept LoadDetected
                then supporting;

            transition supporting_to_assistingTransfer
                first supporting
                accept TransferAssistRequested
                then assistingTransfer;

            transition assistingTransfer_to_supporting
                first assistingTransfer
                accept TransferComplete
                then supporting;

            transition supporting_to_ready
                first supporting
                accept LoadRemoved
                then ready;

            transition ready_to_faultSafe
                first ready
                accept FaultDetected
                then faultSafe;

            transition supporting_to_faultSafe
                first supporting
                accept FaultDetected
                then faultSafe;

            transition faultSafe_to_initializing
                first faultSafe
                accept FaultCleared
                then initializing;
        }
    }

    part def LayeredSupportCore {
        attribute foamLayerThickness : Length = 0.08 [m];
        attribute airCellLayerThickness : Length = 0.07 [m];
        attribute baseLayerThickness : Length = 0.03 [m];

        port loadPort : MechanicalLoadPort;
        port sensorPort : MechanicalLoadPort;
        port actuationInput : AirFlowPort;

        part topComplianceLayer : ViscoelasticLayer;
        part adaptiveAirLayer : AirCellLayer;
        part structuralBaseLayer : StructuralBaseLayer;

        connection topToAirLayer connect topComplianceLayer.lowerFace to adaptiveAirLayer.upperFace;
        connection airToBaseLayer connect adaptiveAirLayer.lowerFace to structuralBaseLayer.upperFace;
    }

    part def ViscoelasticLayer {
        attribute density : Real = 55.0;
        attribute indentationForceDeflection : Force = 130 [N];
        port upperFace : MechanicalLoadPort;
        port lowerFace : MechanicalLoadPort;
    }

    part def AirCellLayer {
        attribute zoneCount : Integer = 9;
        attribute nominalCellPressure : Pressure = 2.50 [kPa];
        attribute maximumCellPressure : Pressure = 6.00 [kPa];
        port upperFace : MechanicalLoadPort;
        port lowerFace : MechanicalLoadPort;
        port airSupply : AirFlowPort;
    }

    part def StructuralBaseLayer {
        attribute stiffness : Real = 0.92;
        attribute deflectionLimit : Length = 0.015 [m];
        port upperFace : MechanicalLoadPort;
    }

    part def PressureSensorArray {
        attribute sensorCount : Integer = 81;
        attribute samplePeriod : Time = 0.10 [s];
        attribute pressureResolution : Pressure = 0.05 [kPa];

        port pressureInput : MechanicalLoadPort;
        port pressureMapOutput : StatusPort;

        action measurePressureMap {
            out item map : BodyPressureMap;
        }
    }

    part def PneumaticActuatorArray {
        attribute pumpMaximumPower : Power = 35 [W];
        attribute valveCount : Integer = 9;
        attribute inflationTime : Time = 8 [s];

        port controlInput : CommandPort;
        port airOutput : AirFlowPort;

        action setZoneFirmness {
            in item command : SupportCommand;
        }
    }

    part def SurfaceController {
        attribute controlPeriod : Time = 0.25 [s];
        attribute targetPeakPressure : Pressure = 3.50 [kPa];
        attribute minimumFirmness : Ratio = 0.20;
        attribute maximumFirmness : Ratio = 1.00;

        port commandInput : CommandPort;
        port pressureMapInput : StatusPort;
        port airControlOutput : CommandPort;
        port statusOutput : StatusPort;
        port powerInput : PowerPort;

        action regulateSurface {
            in item command : SupportCommand;
            in item measuredStatus : SupportStatus;
            out item actuatorCommand : SupportCommand;
            out item reportedStatus : SupportStatus;
        }

        action disableActuation {
            out item actuatorCommand : SupportCommand;
        }
    }

    part def DurableCover {
        attribute coefficientOfFriction : Real = 0.55;
        attribute liquidIngressRating : String = "IPX4";
        attribute cleanableSurface : Boolean = true;
        attribute surfaceTemperatureLimit : Temperature = 42 [K];
    }

    part def PerimeterFrame {
        attribute railHeight : Length = 0.04 [m];
        attribute lateralStiffness : Real = 0.85;
        attribute edgeSupportWidth : Length = 0.08 [m];
    }

    requirement def PrimaryFunctionRequirement {
        subject surface : SupportSurfaceSystem;
        doc /* The support surface shall provide a stable load-bearing interface that distributes the supported load over a broad contact area and limits localized pressure. */
        require constraint {
            surface.maximumSupportedMass >= 180 [kg]
        }
    }

    requirement def PressureDistributionRequirement {
        subject surface : SupportSurfaceSystem;
        require constraint {
            surface.maximumAllowablePeakPressure <= 4.00 [kPa]
        }
    }

    requirement def StabilityRequirement {
        subject surface : SupportSurfaceSystem;
        require constraint {
            surface.minimumStableContactArea >= 0.35 [m^2]
        }
    }

    requirement def ControlResponseRequirement {
        subject controller : SurfaceController;
        require constraint {
            controller.controlPeriod <= 0.25 [s]
        }
    }

    requirement def PowerRequirement {
        subject actuatorArray : PneumaticActuatorArray;
        require constraint {
            actuatorArray.pumpMaximumPower <= 35 [W]
        }
    }

    part supportSurfaceSystem : SupportSurfaceSystem;
}