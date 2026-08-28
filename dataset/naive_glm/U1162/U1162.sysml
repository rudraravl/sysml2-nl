package PicoAssemblySystem {
    public import ScalarValues::*;

    // ============ Value Types ============
    value def Length :> Real { unit 'pm'; }
    value def Force :> Real { unit 'fN'; }
    value def Temperature :> Real { unit 'K'; }
    value def Pressure :> Real { unit 'mPa'; }
    value def Voltage :> Real { unit 'V'; }
    value def Current :> Real { unit 'pA'; }
    value def Frequency :> Real { unit 'Hz'; }
    value def Mass :> Real { unit 'amu'; }

    // ============ Enumerations ============
    enum def AtomType { carbon; silicon; oxygen; hydrogen; nitrogen; }
    enum def SystemMode { off; initializing; ready; scanning; manipulating; assembling; complete; faulted; }
    enum def ManipPhase { idle; approaching; attaching; moving; releasing; }

    // ============ Item Definitions ============
    item def Coordinate {
        attribute x : Length;
        attribute y : Length;
        attribute z : Length;
    }

    item def Atom {
        attribute type : AtomType;
        attribute position : Coordinate;
        attribute mass : Mass;
    }

    item def AtomicMap {
        attribute resolution : Length;
        attribute atoms : Atom[0..*];
        attribute areaWidth : Length;
        attribute areaHeight : Length;
    }

    item def AssemblyStep {
        attribute stepId : Integer;
        attribute atomType : AtomType;
        attribute sourcePosition : Coordinate;
        attribute targetPosition : Coordinate;
    }

    item def AssemblyPlan {
        attribute planId : String;
        attribute steps : AssemblyStep[0..*];
        attribute currentStepIndex : Integer;
    }

    item def ProbeMeasurement {
        attribute tunnelingCurrent : Current;
        attribute deflection : Length;
        attribute position : Coordinate;
    }

    item def EnvironmentStatus {
        attribute pressure : Pressure;
        attribute temperature : Temperature;
        attribute stable : Boolean;
    }

    item def ControlSignal {
        attribute voltage : Voltage;
        attribute positionAdjustment : Coordinate;
    }

    // ============ Port Definitions ============
    port def MeasurementOut {
        out measurement : ProbeMeasurement;
    }

    port def MeasurementIn {
        in measurement : ProbeMeasurement;
    }

    port def PositionCommandPort {
        in command : Coordinate;
        out position : Coordinate;
    }

    port def ForceControlPort {
        in setpoint : Force;
        out actualForce : Force;
    }

    port def ControlSignalPort {
        out signal : ControlSignal;
        in signal : ControlSignal;
    }

    port def MapDataPort {
        out map : AtomicMap;
        in plan : AssemblyPlan;
    }

    port def AtomSupplyPort {
        out atom : Atom;
        in atom : Atom;
    }

    port def EnvironmentPort {
        out status : EnvironmentStatus;
    }

    // ============ Part Definitions ============

    part def UltraHighVacuumChamber {
        port envOut : EnvironmentPort;

        attribute targetPressure : Pressure = 1e-7;
        attribute targetTemperature : Temperature = 4.2;
        attribute currentPressure : Pressure;
        attribute currentTemperature : Temperature;
        attribute stable : Boolean = false;

        exhibit state chamberState {
            entry; then Unpumped;

            state Unpumped {
                entry action startPumpDown;
            }

            transition pumpDownComplete
                first Unpumped
                if currentPressure <= targetPressure
                then Cooled;

            state Cooled {
                entry action startCooling;
            }

            transition coolComplete
                first Cooled
                if currentTemperature <= targetTemperature
                then Stabilized;

            state Stabilized {
                entry action markStable;
            }
        }

        action startPumpDown {
            out pressure : Pressure;
        }

        action startCooling {
            out temperature : Temperature;
        }

        action markStable {
            out stable : Boolean;
        }
    }

    part def PiezoelectricActuator {
        port posPort : PositionCommandPort;
        port controlIn : ControlSignalPort;

        attribute resolution : Length = 1;
        attribute maxRange : Length = 100000;
        attribute currentCommand : Coordinate;
        attribute currentPosition : Coordinate;
        attribute appliedVoltage : Voltage;

        action move {
            in target : Coordinate;
            out achieved : Coordinate;
        }

        action fineAdjust {
            in signal : ControlSignal;
            out position : Coordinate;
        }

        action hold {
            in position : Coordinate;
        }
    }

    part def ScanningProbe {
        port measOut : MeasurementOut;
        port posPort : PositionCommandPort;
        port atomIn : AtomSupplyPort;

        attribute tipRadius : Length = 10;
        attribute resonanceFreq : Frequency = 30000;
        attribute carriedAtom : Atom[0..1];
        attribute biasVoltage : Voltage = 0.01;

        action scan {
            in area : Coordinate;
            out measurement : ProbeMeasurement;
        }

        action approach {
            in target : Coordinate;
            out measurement : ProbeMeasurement;
        }

        action attach {
            in atom : Atom;
            out success : Boolean;
        }

        action release {
            in position : Coordinate;
            out success : Boolean;
        }
    }

    part def HighResolutionImager {
        port measIn : MeasurementIn;
        port mapPort : MapDataPort;

        attribute scanResolution : Length = 5;
        attribute scanRate : Frequency = 10;

        action createAtomicMap {
            in scanData : ProbeMeasurement[0..*];
            out map : AtomicMap;
        }

        action identifyAtoms {
            in map : AtomicMap;
            out identified : Atom[0..*];
        }
    }

    part def AtomicForceController {
        port forcePort : ForceControlPort;
        port measIn : MeasurementIn;
        port controlOut : ControlSignalPort;

        attribute forceResolution : Force = 1;
        attribute maxForce : Force = 1000;
        attribute currentSetpoint : Force;
        attribute currentForce : Force;

        action regulateForce {
            in measurement : ProbeMeasurement;
            in setpoint : Force;
            out signal : ControlSignal;
        }

        action approachAtom {
            in target : Coordinate;
            in maxForce : Force;
            out achieved : Boolean;
        }

        action pickupAtom {
            in atom : Atom;
            out success : Boolean;
        }

        action placeAtom {
            in position : Coordinate;
            out success : Boolean;
        }
    }

    part def PositionFeedbackSystem {
        port posPort : PositionCommandPort;

        attribute accuracy : Length = 50;
        attribute updateRate : Frequency = 10000;
        attribute currentPosition : Coordinate;
        attribute calibrated : Boolean = false;

        action monitorPosition {
            in command : Coordinate;
            out measured : Coordinate;
        }

        action calibrate {
            out offset : Coordinate;
        }
    }

    part def AtomicReservoir {
        port supplyPort : AtomSupplyPort;

        attribute carbonCount : Integer = 10000;
        attribute siliconCount : Integer = 5000;
        attribute oxygenCount : Integer = 5000;
        attribute hydrogenCount : Integer = 8000;
        attribute nitrogenCount : Integer = 4000;

        action dispense {
            in type : AtomType;
            out atom : Atom;
        }

        action refill {
            in type : AtomType;
            in quantity : Integer;
        }

        action checkSupply {
            out available : Boolean;
        }
    }

    part def AssemblyController {
        port mapPort : MapDataPort;
        port forcePort : ForceControlPort;
        port posPort : PositionCommandPort;
        port supplyPort : AtomSupplyPort;
        port envIn : EnvironmentPort;

        attribute currentPlan : AssemblyPlan;
        attribute mode : SystemMode = SystemMode::off;
        attribute currentMap : AtomicMap;
        attribute envStatus : EnvironmentStatus;
        attribute currentStep : AssemblyStep;

        exhibit state systemOperation {
            entry; then Off;

            state Off {
                entry action powerOff;
            }

            transition powerOn
                first Off
                if true
                then Initializing;

            state Initializing {
                entry action initialize;
            }

            transition initDone
                first Initializing
                if envStatus.stable == true
                then Ready;

            state Ready {
                entry action reportReady;
            }

            transition startScan
                first Ready
                if currentPlan.steps->size() > 0
                then Scanning;

            state Scanning {
                entry action performScan;
            }

            transition scanComplete
                first Scanning
                if currentMap.atoms->size() > 0
                then Manipulating;

            state Manipulating {
                exhibit state manipulationSequence {
                    entry; then MIdle;

                    state MIdle;

                    transition beginApproach
                        first MIdle
                        if true
                        then Approaching;

                    state Approaching {
                        entry action doApproach;
                    }

                    transition madeContact
                        first Approaching
                        if true
                        then Attaching;

                    state Attaching {
                        entry action doAttach;
                    }

                    transition atomAttached
                        first Attaching
                        if true
                        then Moving;

                    state Moving {
                        entry action doMove;
                    }

                    transition reachedTarget
                        first Moving
                        if true
                        then Releasing;

                    state Releasing {
                        entry action doRelease;
                    }

                    transition atomReleased
                        first Releasing
                        if true
                        then MIdle;
                }
            }

            transition manipComplete
                first Manipulating
                if true
                then Assembling;

            state Assembling {
                entry action updateStructure;
            }

            transition nextStep
                first Assembling
                if currentPlan.currentStepIndex < currentPlan.steps->size()
                then Scanning;

            transition allDone
                first Assembling
                if currentPlan.currentStepIndex >= currentPlan.steps->size()
                then Complete;

            state Complete {
                entry action reportComplete;
            }

            transition errorDetected
                first Off | Initializing | Ready | Scanning | Manipulating | Assembling | Complete
                if mode == SystemMode::faulted
                then Faulted;

            state Faulted {
                entry action reportFault;
            }
        }

        action powerOff { }
        action initialize { out ready : Boolean; }
        action reportReady { }
        action performScan { out map : AtomicMap; }
        action doApproach { in step : AssemblyStep; out success : Boolean; }
        action doAttach { in atom : Atom; out success : Boolean; }
        action doMove { in target : Coordinate; out success : Boolean; }
        action doRelease { in position : Coordinate; out success : Boolean; }
        action updateStructure { in step : AssemblyStep; out complete : Boolean; }
        action reportComplete { }
        action reportFault { }
        action loadPlan { in plan : AssemblyPlan; }
    }

    // ============ Top-Level System ============
    part def PicoAssembler {
        part chamber : UltraHighVacuumChamber;
        part probe : ScanningProbe;
        part actuator : PiezoelectricActuator;
        part imager : HighResolutionImager;
        part forceController : AtomicForceController;
        part feedback : PositionFeedbackSystem;
        part reservoir : AtomicReservoir;
        part controller : AssemblyController;

        // Environment monitoring: chamber -> controller
        connect chamber.envOut::status to controller.envIn::status;

        // Probe measurements -> imager and force controller
        connect probe.measOut::measurement to imager.measIn::measurement;
        connect probe.measOut::measurement to forceController.measIn::measurement;

        // Force control loop: controller <-> force controller
        connect controller.forcePort::setpoint to forceController.forcePort::setpoint;
        connect forceController.forcePort::actualForce to controller.forcePort::actualForce;

        // Force controller -> actuator (fine control signal)
        connect forceController.controlOut::signal to actuator.controlIn::signal;

        // Position command loop: controller -> feedback -> actuator
        connect controller.posPort::command to feedback.posPort::command;
        connect feedback.posPort::position to controller.posPort::position;
        connect feedback.posPort::command to actuator.posPort::command;
        connect actuator.posPort::position to feedback.posPort::position;

        // Actuator drives probe position
        connect actuator.posPort::position to probe.posPort::position;
        connect controller.posPort::command to probe.posPort::command;

        // Map data exchange: imager <-> controller
        connect imager.mapPort::map to controller.mapPort::map;
        connect controller.mapPort::plan to imager.mapPort::plan;

        // Atom supply chain: reservoir -> controller -> probe
        connect reservoir.supplyPort::atom to controller.supplyPort::atom;
        connect controller.supplyPort::atom to probe.atomIn::atom;
    }

    // ============ Requirements ============
    requirement def VacuumRequirement {
        subject chamber : UltraHighVacuumChamber;
        require chamber.currentPressure <= 1e-7;
    }

    requirement def TemperatureRequirement {
        subject chamber : UltraHighVacuumChamber;
        require chamber.currentTemperature <= 4.2;
    }

    requirement def PositioningAccuracyRequirement {
        subject feedback : PositionFeedbackSystem;
        require feedback.accuracy <= 50;
    }

    requirement def ForceResolutionRequirement {
        subject forceController : AtomicForceController;
        require forceController.forceResolution <= 1;
    }

    requirement def ActuatorResolutionRequirement {
        subject actuator : PiezoelectricActuator;
        require actuator.resolution <= 1;
    }

    requirement def ScanResolutionRequirement {
        subject imager : HighResolutionImager;
        require imager.scanResolution <= 10;
    }

    requirement def AssemblyCompletenessRequirement {
        subject controller : AssemblyController;
        require controller.currentPlan.currentStepIndex >= controller.currentPlan.steps->size();
    }

    requirement def SingleAtomManipulationRequirement {
        subject probe : ScanningProbe;
        require probe.carriedAtom->size() <= 1;
    }

    requirement vacuumReq : VacuumRequirement;
    requirement tempReq : TemperatureRequirement;
    requirement posAccReq : PositioningAccuracyRequirement;
    requirement forceResReq : ForceResolutionRequirement;
    requirement actuatorResReq : ActuatorResolutionRequirement;
    requirement scanResReq : ScanResolutionRequirement;
    requirement completenessReq : AssemblyCompletenessRequirement;
    requirement singleAtomReq : SingleAtomManipulationRequirement;

    // ============ Satisfaction ============
    satisfaction vacuumReq by chamber;
    satisfaction tempReq by chamber;
    satisfaction posAccReq by feedback;
    satisfaction forceResReq by forceController;
    satisfaction actuatorResReq by actuator;
    satisfaction scanResReq by imager;
    satisfaction completenessReq by controller;
    satisfaction singleAtomReq by probe;
}
