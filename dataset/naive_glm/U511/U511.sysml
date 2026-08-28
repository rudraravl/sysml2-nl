package HCNGDispenserSystem {

    import ScalarValues::*;
    import ISQ::*;

    value type Pressure > Real { unit "Pa"; }
    value type Temperature > Real { unit "K"; }
    value type FlowRate > Real { unit "kg/s"; }
    value type VolumeFraction > Real { unit "1"; }
    value type Mass > Real { unit "kg"; }
    value type Currency > Real { unit "USD"; }
    value type Energy > Real { unit "J"; }
    value type Duration > Real { unit "s"; }

    item def Hydrogen;
    item def CNG;
    item def HCNGBlend {
        attribute hydrogenFraction : VolumeFraction;
        attribute cngFraction : VolumeFraction := 1.0 - hydrogenFraction;
    }

    attribute def BlendRequest {
        attribute hydrogenFraction : VolumeFraction;
        attribute targetPressure : Pressure;
        attribute paymentAuthorized : Boolean;
    }

    attribute def SensorReading {
        attribute pressure : Pressure;
        attribute temperature : Temperature;
        attribute flowRate : FlowRate;
    }

    attribute def SafetyStatus {
        attribute nozzleLocked : Boolean;
        attribute pressureOk : Boolean;
        attribute temperatureOk : Boolean;
        attribute leakDetected : Boolean;
    }

    enum def BlendType {
        PURE_CNG;
        HCNG_10;
        HCNG_20;
        HCNG_30;
    }

    port def FuelFlowPort {
        out item fuel : HCNGBlend;
    }

    port def HydrogenFlowPort {
        out item hydrogen : Hydrogen;
    }

    port def CNGFlowPort {
        out item cng : CNG;
    }

    port def ControlSignalPort {
        in attribute command : String;
        out attribute status : String;
    }

    port def SensorDataPort {
        out attribute reading : SensorReading;
    }

    port def SafetySignalPort {
        out attribute status : SafetyStatus;
    }

    part def HydrogenStorageTank {
        attribute maxPressure : Pressure := 70000000;
        attribute currentPressure : Pressure := 70000000;
        attribute storedMass : Mass := 50;
        port fuelOut : HydrogenFlowPort;
    }

    part def CNGStorageTank {
        attribute maxPressure : Pressure := 25000000;
        attribute currentPressure : Pressure := 25000000;
        attribute storedMass : Mass := 200;
        port fuelOut : CNGFlowPort;
    }

    part def BlendingValve {
        attribute hydrogenFraction : VolumeFraction;
        attribute blendRate : FlowRate;
        port hydrogenIn : HydrogenFlowPort { in item hydrogen : Hydrogen; }
        port cngIn : CNGFlowPort { in item cng : CNG; }
        port blendOut : FuelFlowPort;
        port control : ControlSignalPort;

        action def performBlending {
            in h : Hydrogen;
            in c : CNG;
            out blend : HCNGBlend;
            attribute ratio : VolumeFraction;
        }
    }

    part def CompressionModule {
        attribute targetPressure : Pressure;
        attribute currentPressure : Pressure;
        port fuelIn : FuelFlowPort { in item fuel : HCNGBlend; }
        port fuelOut : FuelFlowPort;
        port control : ControlSignalPort;

        action def compress {
            in fuelIn : HCNGBlend;
            out fuelOut : HCNGBlend;
            attribute inputPressure : Pressure;
            attribute outputPressure : Pressure;
        }
    }

    part def DispensingNozzle {
        attribute locked : Boolean := false;
        attribute connected : Boolean := false;
        port fuelIn : FuelFlowPort { in item fuel : HCNGBlend; }
        port control : ControlSignalPort;
        port safety : SafetySignalPort;

        action def lockToVehicle {
            in vehicleReceptacle;
            out locked : Boolean;
        }
    }

    part def PressureSensor {
        attribute measuredPressure : Pressure;
        port dataOut : SensorDataPort;
        port control : ControlSignalPort;
    }

    part def TemperatureSensor {
        attribute measuredTemperature : Temperature;
        port dataOut : SensorDataPort;
        port control : ControlSignalPort;
    }

    part def FlowMeter {
        attribute measuredFlowRate : FlowRate;
        attribute totalMassDispensed : Mass := 0;
        port dataOut : SensorDataPort;
        port control : ControlSignalPort;
    }

    part def LeakDetectionSystem {
        attribute leakThreshold : VolumeFraction := 0.01;
        attribute leakDetected : Boolean := false;
        port safetyOut : SafetySignalPort;
        port control : ControlSignalPort;
    }

    part def SafetyShutoffValve {
        attribute open : Boolean := false;
        port fuelIn : FuelFlowPort { in item fuel : HCNGBlend; }
        port fuelOut : FuelFlowPort;
        port control : ControlSignalPort;

        action def emergencyClose {
            out closed : Boolean := true;
        }
    }

    part def VentingSystem {
        attribute venting : Boolean := false;
        attribute ventPressure : Pressure;
        port control : ControlSignalPort;
        port fuelIn : FuelFlowPort { in item fuel : HCNGBlend; }

        action def vent {
            in fuel : HCNGBlend;
            out released : Boolean;
        }
    }

    part def UserInterface {
        attribute displayMessage : String;
        attribute selectedBlend : BlendType;
        attribute paymentAmount : Currency;
        port control : ControlSignalPort;

        action def authenticatePayment {
            in amount : Currency;
            out authorized : Boolean;
        }

        action def selectBlend {
            out blend : BlendType;
        }
    }

    part def ControlModule {
        attribute currentBlendRequest : BlendRequest;
        attribute currentSafetyStatus : SafetyStatus;
        attribute systemActive : Boolean := false;
        attribute emergencyShutdown : Boolean := false;

        port uiControl : ControlSignalPort;
        port blendingControl : ControlSignalPort;
        port compressionControl : ControlSignalPort;
        port nozzleControl : ControlSignalPort;
        port shutoffControl : ControlSignalPort;
        port ventingControl : ControlSignalPort;
        port pressureSensorData : SensorDataPort { in attribute reading : SensorReading; }
        port temperatureSensorData : SensorDataPort { in attribute reading : SensorReading; }
        port flowMeterData : SensorDataPort { in attribute reading : SensorReading; }
        port leakSafety : SafetySignalPort { in attribute status : SafetyStatus; }
        port nozzleSafety : SafetySignalPort { in attribute status : SafetyStatus; }

        state machine def DispenserOperation {
            state idle;
            state authenticating;
            state preparingBlend;
            state dispensing;
            state completing;
            state fault;

            transition init idle -> authenticating
                when uiControl.status == "paymentRequested";

            transition auth authenticating -> preparingBlend
                when uiControl.status == "paymentAuthorized"
                and nozzleSafety.status.nozzleLocked == true;

            transition authFault authenticating -> fault
                when uiControl.status == "paymentDenied";

            transition prep preparingBlend -> dispensing
                when blendingControl.status == "blendReady"
                and compressionControl.status == "pressureReached"
                and pressureSensorData.reading.pressure <= 70000000
                and temperatureSensorData.reading.temperature <= 323.15
                and leakSafety.status.leakDetected == false;

            transition prepFault preparingBlend -> fault
                when leakSafety.status.leakDetected == true
                or pressureSensorData.reading.pressure > 70000000
                or temperatureSensorData.reading.temperature > 323.15;

            transition disp dispensing -> completing
                when flowMeterData.reading.flowRate == 0
                or uiControl.status == "stopRequested";

            transition dispFault dispensing -> fault
                when leakSafety.status.leakDetected == true
                or pressureSensorData.reading.pressure > 70000000
                or temperatureSensorData.reading.temperature > 323.15
                or flowMeterData.reading.flowRate > 0.5;

            transition complete completing -> idle
                when uiControl.status == "transactionComplete";

            transition recover fault -> idle
                when uiControl.status == "faultReset"
                and leakSafety.status.leakDetected == false;
        }

        action def evaluateSafety {
            in safety : SafetyStatus;
            in sensor : SensorReading;
            out safe : Boolean;
        }

        action def computeBlendRatio {
            in blendType : BlendType;
            out ratio : VolumeFraction;
        }
    }

    part def HCNGDispenser {
        part hydrogenTank : HydrogenStorageTank;
        part cngTank : CNGStorageTank;
        part blendingValve : BlendingValve;
        part compressionModule : CompressionModule;
        part safetyShutoffValve : SafetyShutoffValve;
        part dispensingNozzle : DispensingNozzle;
        part pressureSensor : PressureSensor;
        part temperatureSensor : TemperatureSensor;
        part flowMeter : FlowMeter;
        part leakDetection : LeakDetectionSystem;
        part ventingSystem : VentingSystem;
        part userInterface : UserInterface;
        part controlModule : ControlModule;

        connect hydrogenTank.fuelOut to blendingValve.hydrogenIn;
        connect cngTank.fuelOut to blendingValve.cngIn;
        connect blendingValve.blendOut to compressionModule.fuelIn;
        connect compressionModule.fuelOut to safetyShutoffValve.fuelIn;
        connect safetyShutoffValve.fuelOut to dispensingNozzle.fuelIn;
        connect compressionModule.fuelOut to ventingSystem.fuelIn;

        connect controlModule.uiControl to userInterface.control;
        connect controlModule.blendingControl to blendingValve.control;
        connect controlModule.compressionControl to compressionModule.control;
        connect controlModule.nozzleControl to dispensingNozzle.control;
        connect controlModule.shutoffControl to safetyShutoffValve.control;
        connect controlModule.ventingControl to ventingSystem.control;

        connect pressureSensor.dataOut to controlModule.pressureSensorData;
        connect temperatureSensor.dataOut to controlModule.temperatureSensorData;
        connect flowMeter.dataOut to controlModule.flowMeterData;
        connect leakDetection.safetyOut to controlModule.leakSafety;
        connect dispensingNozzle.safety to controlModule.nozzleSafety;

        connect pressureSensor.control to controlModule.compressionControl;
        connect temperatureSensor.control to controlModule.compressionControl;
        connect flowMeter.control to controlModule.shutoffControl;
        connect leakDetection.control to controlModule.shutoffControl;
    }

    requirement def SafetyRequirement {
        subject dispenser : HCNGDispenser;
        objective {
            doc "The dispenser shall immediately stop fuel flow and enter emergency shutdown when a leak is detected or any monitored parameter exceeds safe limits.";
        }
    }

    requirement def BlendPrecisionRequirement {
        subject blendingValve : BlendingValve;
        attribute tolerance : VolumeFraction := 0.02;
        objective {
            doc "The blending valve shall produce HCNG blends with hydrogen content up to 30% by volume within a tolerance of 2%.";
        }
    }

    requirement def PressureControlRequirement {
        subject compressionModule : CompressionModule;
        attribute maxPressure : Pressure := 70000000;
        objective {
            doc "The compression module shall deliver fuel at the target pressure without exceeding 70 MPa.";
        }
    }

    requirement def AuthenticationRequirement {
        subject userInterface : UserInterface;
        objective {
            doc "The user interface shall authenticate payment before any fuel dispensing begins.";
        }
    }

    requirement def NozzleLockRequirement {
        subject dispensingNozzle : DispensingNozzle;
        objective {
            doc "The dispensing nozzle shall be securely locked to the vehicle before fuel flow is permitted.";
        }
    }

    requirement def VentingRequirement {
        subject ventingSystem : VentingSystem;
        objective {
            doc "The venting system shall safely release pressure when system pressure exceeds safe operating limits.";
        }
    }

    requirement def StateTransitionRequirement {
        subject controlModule : ControlModule;
        objective {
            doc "The control module shall transition through idle, authenticating, preparingBlend, dispensing, completing, and fault states as defined by the DispenserOperation state machine.";
        }
    }

    satisfaction satisfySafety by HCNGDispenser::controlModule satisfies SafetyRequirement;
    satisfaction satisfyBlend by HCNGDispenser::blendingValve satisfies BlendPrecisionRequirement;
    satisfaction satisfyPressure by HCNGDispenser::compressionModule satisfies PressureControlRequirement;
    satisfaction satisfyAuth by HCNGDispenser::userInterface satisfies AuthenticationRequirement;
    satisfaction satisfyNozzle by HCNGDispenser::dispensingNozzle satisfies NozzleLockRequirement;
    satisfaction satisfyVenting by HCNGDispenser::ventingSystem satisfies VentingRequirement;
    satisfaction satisfyStates by HCNGDispenser::controlModule satisfies StateTransitionRequirement;

}
