package WingSystemModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Length :> Real {
        unit = "m";
    }

    attribute def Area :> Real {
        unit = "m^2";
    }

    attribute def Angle :> Real {
        unit = "deg";
    }

    attribute def Force :> Real {
        unit = "N";
    }

    attribute def Pressure :> Real {
        unit = "Pa";
    }

    attribute def Speed :> Real {
        unit = "m/s";
    }

    attribute def Mass :> Real {
        unit = "kg";
    }

    attribute def Moment :> Real {
        unit = "N*m";
    }

    attribute def Dimensionless :> Real;

    item def AirFlow {
        attribute density : Real = 1.225;
        attribute dynamicPressure : Pressure;
        attribute velocity : Speed;
        attribute angleOfAttack : Angle;
    }

    item def LiftLoad {
        attribute lift : Force;
        attribute rollingMoment : Moment;
        attribute pitchingMoment : Moment;
    }

    item def DragLoad {
        attribute drag : Force;
    }

    item def Fuel {
        attribute quantity : Mass;
        attribute pressure : Pressure;
    }

    item def ControlCommand {
        attribute flapAngleCommand : Angle;
        attribute aileronAngleCommand : Angle;
        attribute spoilerDeployCommand : Dimensionless;
    }

    item def HealthStatus {
        attribute structuralMargin : Dimensionless;
        attribute actuatorAvailable : Boolean;
        attribute fuelLeakDetected : Boolean;
        attribute iceDetected : Boolean;
    }

    port def AeroSurfacePort {
        in item incomingAir : AirFlow;
        out item liftLoad : LiftLoad;
        out item dragLoad : DragLoad;
    }

    port def ControlInputPort {
        in item command : ControlCommand;
    }

    port def FuelTransferPort {
        inout item fuelFlow : Fuel;
    }

    port def StructuralLoadPort {
        out item load : LiftLoad;
    }

    port def HealthPort {
        out item status : HealthStatus;
    }

    action def GenerateLift {
        in item flow : AirFlow;
        in attribute planformArea : Area;
        in attribute liftCoefficient : Dimensionless;
        out item liftResult : LiftLoad;

        attribute computedLift : Force;
        attribute computedPitchingMoment : Moment;

        first start;
        then calculateLift;
        then publishLift;
        then done;

        action calculateLift {
            attribute dynamicLift : Force;
        }

        action publishLift;
    }

    action def AdjustCamber {
        in item command : ControlCommand;
        out attribute flapDeflection : Angle;
        out attribute aileronDeflection : Angle;

        first receiveCommand;
        then limitCommand;
        then positionSurfaces;
        then complete;

        action receiveCommand;
        action limitCommand;
        action positionSurfaces;
    }

    action def TransferFuel {
        inout item fuel : Fuel;
        in attribute requestedBalanceMass : Mass;
        out attribute transferredMass : Mass;

        first assessBalance;
        then openValves;
        then pumpFuel;
        then closeValves;
        then reportTransfer;

        action assessBalance;
        action openValves;
        action pumpFuel;
        action closeValves;
        action reportTransfer;
    }

    state def WingOperatingState {
        entry action initializeWingMonitoring;

        state GroundIdle;
        state Taxi;
        state TakeoffHighLift;
        state CruiseLift;
        state ManeuverLoad;
        state LandingHighLift;
        state FaultAccommodation;
        state MaintenanceSafe;

        transition first GroundIdle;

        transition GroundIdle_to_Taxi
            first GroundIdle
            then Taxi;

        transition Taxi_to_TakeoffHighLift
            first Taxi
            then TakeoffHighLift;

        transition TakeoffHighLift_to_CruiseLift
            first TakeoffHighLift
            then CruiseLift;

        transition CruiseLift_to_ManeuverLoad
            first CruiseLift
            then ManeuverLoad;

        transition ManeuverLoad_to_CruiseLift
            first ManeuverLoad
            then CruiseLift;

        transition CruiseLift_to_LandingHighLift
            first CruiseLift
            then LandingHighLift;

        transition LandingHighLift_to_Taxi
            first LandingHighLift
            then Taxi;

        transition AnyOperational_to_FaultAccommodation
            first CruiseLift
            then FaultAccommodation;

        transition FaultAccommodation_to_MaintenanceSafe
            first FaultAccommodation
            then MaintenanceSafe;
    }

    part def Spar {
        attribute spanwiseLength : Length;
        attribute bendingStrength : Moment;
        attribute mass : Mass;
        port structuralPort : StructuralLoadPort;
    }

    part def Rib {
        attribute chordwiseLength : Length;
        attribute spacing : Length;
        attribute mass : Mass;
    }

    part def WingSkin {
        attribute wettedArea : Area;
        attribute thickness : Length;
        attribute allowablePressure : Pressure;
        port aeroPort : AeroSurfacePort;
    }

    part def LeadingEdgeDevice {
        attribute deployedAngle : Angle;
        attribute maximumAngle : Angle = 25.0;
        port controlPort : ControlInputPort;
    }

    part def TrailingEdgeFlap {
        attribute deployedAngle : Angle;
        attribute maximumAngle : Angle = 40.0;
        port controlPort : ControlInputPort;
    }

    part def Aileron {
        attribute deflectionAngle : Angle;
        attribute maximumDeflection : Angle = 25.0;
        port controlPort : ControlInputPort;
    }

    part def Spoiler {
        attribute deploymentRatio : Dimensionless;
        port controlPort : ControlInputPort;
    }

    part def WingFuelTank {
        attribute capacity : Mass;
        attribute containedFuel : Mass;
        attribute ullagePressure : Pressure;
        port fuelPort : FuelTransferPort;
        port healthPort : HealthPort;
    }

    part def WingControlActuator {
        attribute availableTorque : Moment;
        attribute responseTime : Real;
        port commandPort : ControlInputPort;
        port healthPort : HealthPort;
    }

    part def WingHealthMonitor {
        attribute measuredStrainMargin : Dimensionless;
        attribute measuredIceAccretion : Length;
        port healthPort : HealthPort;
    }

    part def Wing {
        attribute span : Length = 35.8;
        attribute rootChord : Length = 5.6;
        attribute tipChord : Length = 1.8;
        attribute planformArea : Area = 122.4;
        attribute sweepAngle : Angle = 25.0;
        attribute dihedralAngle : Angle = 5.5;
        attribute structuralMass : Mass = 5200.0;
        attribute cruiseLiftCoefficient : Dimensionless = 0.52;
        attribute maximumLiftCoefficient : Dimensionless = 2.35;

        port aeroPort : AeroSurfacePort;
        port commandPort : ControlInputPort;
        port fuelPort : FuelTransferPort;
        port structuralLoadPort : StructuralLoadPort;
        port healthPort : HealthPort;

        part frontSpar : Spar {
            attribute spanwiseLength = 35.8;
            attribute bendingStrength = 4100000.0;
            attribute mass = 920.0;
        }

        part rearSpar : Spar {
            attribute spanwiseLength = 35.8;
            attribute bendingStrength = 3600000.0;
            attribute mass = 780.0;
        }

        part ribs[24] : Rib {
            attribute chordwiseLength = 3.4;
            attribute spacing = 1.45;
            attribute mass = 38.0;
        }

        part upperSkin : WingSkin {
            attribute wettedArea = 66.0;
            attribute thickness = 0.018;
            attribute allowablePressure = 85000.0;
        }

        part lowerSkin : WingSkin {
            attribute wettedArea = 66.0;
            attribute thickness = 0.016;
            attribute allowablePressure = 90000.0;
        }

        part leadingEdgeSlat : LeadingEdgeDevice;
        part inboardFlap : TrailingEdgeFlap;
        part outboardFlap : TrailingEdgeFlap;
        part leftAileron : Aileron;
        part rightAileron : Aileron;
        part groundSpoiler[4] : Spoiler;

        part mainFuelTank : WingFuelTank {
            attribute capacity = 6200.0;
            attribute containedFuel = 4800.0;
            attribute ullagePressure = 101325.0;
        }

        part flapActuator : WingControlActuator {
            attribute availableTorque = 12000.0;
            attribute responseTime = 0.8;
        }

        part aileronActuator : WingControlActuator {
            attribute availableTorque = 4500.0;
            attribute responseTime = 0.2;
        }

        part spoilerActuator : WingControlActuator {
            attribute availableTorque = 3200.0;
            attribute responseTime = 0.15;
        }

        part healthMonitor : WingHealthMonitor {
            attribute measuredStrainMargin = 1.45;
            attribute measuredIceAccretion = 0.0;
        }

        perform action liftGeneration : GenerateLift {
            in flow = aeroPort.incomingAir;
            in planformArea = planformArea;
            in liftCoefficient = cruiseLiftCoefficient;
            out liftResult = aeroPort.liftLoad;
        }

        perform action camberAdjustment : AdjustCamber {
            in command = commandPort.command;
        }

        perform action fuelBalancing : TransferFuel {
            inout fuel = fuelPort.fuelFlow;
            in requestedBalanceMass = 450.0;
        }

        exhibit state operatingState : WingOperatingState;

        connect aeroPort to upperSkin.aeroPort;
        connect aeroPort to lowerSkin.aeroPort;

        connect commandPort to leadingEdgeSlat.controlPort;
        connect commandPort to inboardFlap.controlPort;
        connect commandPort to outboardFlap.controlPort;
        connect commandPort to leftAileron.controlPort;
        connect commandPort to rightAileron.controlPort;
        connect commandPort to groundSpoiler.controlPort;
        connect commandPort to flapActuator.commandPort;
        connect commandPort to aileronActuator.commandPort;
        connect commandPort to spoilerActuator.commandPort;

        connect fuelPort to mainFuelTank.fuelPort;

        connect frontSpar.structuralPort to structuralLoadPort;
        connect rearSpar.structuralPort to structuralLoadPort;

        connect healthMonitor.healthPort to healthPort;
        connect mainFuelTank.healthPort to healthPort;
        connect flapActuator.healthPort to healthPort;
        connect aileronActuator.healthPort to healthPort;
        connect spoilerActuator.healthPort to healthPort;
    }

    part def AircraftWingInstallation {
        part leftWing : Wing;
        part rightWing : Wing;

        port leftAirInterface : AeroSurfacePort;
        port rightAirInterface : AeroSurfacePort;
        port flightControlInterface : ControlInputPort;
        port fuelSystemInterface : FuelTransferPort;
        port wingHealthInterface : HealthPort;

        connect leftAirInterface to leftWing.aeroPort;
        connect rightAirInterface to rightWing.aeroPort;
        connect flightControlInterface to leftWing.commandPort;
        connect flightControlInterface to rightWing.commandPort;
        connect fuelSystemInterface to leftWing.fuelPort;
        connect fuelSystemInterface to rightWing.fuelPort;
        connect leftWing.healthPort to wingHealthInterface;
        connect rightWing.healthPort to wingHealthInterface;
    }

    requirement def WingPrimaryFunctionRequirement {
        doc /* The wing system shall generate aerodynamic lift sufficient to support the aircraft in flight while providing controllable roll authority, high-lift capability for takeoff and landing, structural load transfer to the aircraft body, and internal fuel storage. */
    }

    requirement def LiftGenerationRequirement {
        attribute minimumCruiseLift : Force = 620000.0;
        attribute cruiseDynamicPressure : Pressure = 8200.0;

        require constraint {
            minimumCruiseLift >= 620000.0
        }
    }

    requirement def HighLiftRequirement {
        attribute minimumMaximumLiftCoefficient : Dimensionless = 2.20;

        require constraint {
            minimumMaximumLiftCoefficient >= 2.20
        }
    }

    requirement def RollControlRequirement {
        attribute minimumAileronDeflection : Angle = 20.0;
        attribute maximumResponseTime : Real = 0.35;

        require constraint {
            minimumAileronDeflection >= 20.0 and maximumResponseTime <= 0.35
        }
    }

    requirement def StructuralIntegrityRequirement {
        attribute minimumLoadMargin : Dimensionless = 1.25;
        attribute ultimateBendingMoment : Moment = 3500000.0;

        require constraint {
            minimumLoadMargin >= 1.25 and ultimateBendingMoment >= 3500000.0
        }
    }

    requirement def FuelStorageRequirement {
        attribute minimumWingFuelCapacity : Mass = 6000.0;

        require constraint {
            minimumWingFuelCapacity >= 6000.0
        }
    }

    requirement def HealthMonitoringRequirement {
        doc /* The wing system shall report structural margin, actuator availability, fuel leak state, and ice detection state to the aircraft health management system. */
    }

    satisfy WingPrimaryFunctionRequirement by AircraftWingInstallation::leftWing;
    satisfy WingPrimaryFunctionRequirement by AircraftWingInstallation::rightWing;
    satisfy LiftGenerationRequirement by Wing::liftGeneration;
    satisfy HighLiftRequirement by Wing::leadingEdgeSlat;
    satisfy HighLiftRequirement by Wing::inboardFlap;
    satisfy HighLiftRequirement by Wing::outboardFlap;
    satisfy RollControlRequirement by Wing::leftAileron;
    satisfy RollControlRequirement by Wing::rightAileron;
    satisfy StructuralIntegrityRequirement by Wing::frontSpar;
    satisfy StructuralIntegrityRequirement by Wing::rearSpar;
    satisfy FuelStorageRequirement by Wing::mainFuelTank;
    satisfy HealthMonitoringRequirement by Wing::healthMonitor;
}