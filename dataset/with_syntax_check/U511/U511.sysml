package HCNGDispenserSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;

    attribute def PressureValue :> ISQ::PressureValue;
    attribute def TemperatureValue :> ISQ::TemperatureValue;
    attribute def VolumeValue :> ISQ::VolumeValue;
    attribute def MassValue :> ISQ::MassValue;
    attribute def MassFlowRateValue :> ISQ::MassFlowRateValue;
    attribute def PercentageValue :> Real;

    enum def DispenserStateKind {
        idle;
        authenticating;
        blendSelection;
        preparing;
        dispensing;
        completing;
        fault;
    }

    enum def FuelBlendType {
        cng;
        hcng15;
        hcng20;
        hcng25;
        hcng30;
    }

    item def GasFuel {
        attribute pressure : PressureValue;
        attribute temperature : TemperatureValue;
        attribute mass : MassValue;
    }

    item def HydrogenGas specializes GasFuel {
        attribute purity : PercentageValue;
    }

    item def CompressedNaturalGas specializes GasFuel {
        attribute methaneContent : PercentageValue;
    }

    item def HCNGMixture specializes GasFuel {
        attribute hydrogenPercentage : PercentageValue;
        attribute cngPercentage : PercentageValue;
        attribute flowRate : MassFlowRateValue;
    }

    port def GasSupplyPort {
        in item gas : GasFuel;
    }

    port def GasDeliveryPort {
        out item gas : HCNGMixture;
    }

    port def VehicleConnectionPort {
        inout item fuel : HCNGMixture;
    }

    part def StorageTank {
        attribute capacity : VolumeValue;
        attribute currentVolume : VolumeValue;
        attribute storagePressure : PressureValue;
        attribute storageTemperature : TemperatureValue;
        port supplyPort : GasSupplyPort;
    }

    part def PressureSensor {
        attribute measuredPressure : PressureValue;
        out port pressureReading;
    }

    part def TemperatureSensor {
        attribute measuredTemperature : TemperatureValue;
        out port temperatureReading;
    }

    part def FlowMeter {
        attribute measuredFlowRate : MassFlowRateValue;
        attribute totalDispensed : MassValue;
        out port flowReading;
    }

    part def BlendingValve {
        attribute hydrogenRatio : PercentageValue;
        attribute cngRatio : PercentageValue;
        attribute valvePosition : PercentageValue;
        in port h2Input : GasSupplyPort;
        in port cngInput : GasSupplyPort;
        out port mixedOutput : GasDeliveryPort;
    }

    part def CompressionModule {
        attribute targetPressure : PressureValue;
        attribute currentPressure : PressureValue;
        attribute compressionRatio : Real;
        in port gasInput : GasDeliveryPort;
        out port compressedOutput : GasDeliveryPort;
    }

    part def DispensingNozzle {
        attribute isConnected : Boolean;
        attribute nozzlePressure : PressureValue;
        attribute lockEngaged : Boolean;
        in port fuelInput : GasDeliveryPort;
        out port vehicleConnection : VehicleConnectionPort;
    }

    part def SafetyShutoffValve {
        attribute isOpen : Boolean;
        attribute emergencyStop : Boolean;
        in port controlSignal;
        in port gasFlow : GasDeliveryPort;
        out port safeOutput : GasDeliveryPort;
    }

    part def LeakDetectionSystem {
        attribute leakDetected : Boolean;
        attribute sensorCount : Integer;
        attribute alarmActive : Boolean;
        out port alarmSignal;
    }

    part def ControlModule {
        attribute currentState : DispenserStateKind;
        attribute selectedBlend : FuelBlendType;
        attribute targetDispenseAmount : MassValue;
        attribute dispensedAmount : MassValue;
        in port sensorInputs;
        in port userCommands;
        out port valveControls;
        out port displayOutputs;
    }

    part def UserInterface {
        attribute displayMessage : String;
        attribute selectedFuelType : FuelBlendType;
        attribute authenticationStatus : Boolean;
        in port statusUpdates;
        out port userSelections;
    }

    part def VentingSystem {
        attribute ventOpen : Boolean;
        attribute ventPressure : PressureValue;
        in port ventControl;
        out port ventPort;
    }

    action def AuthenticateUser {
        in userId : String;
        in paymentMethod : String;
        out authenticationResult : Boolean;
        out sessionId : String;
    }

    action def SelectFuelBlend {
        in requestedBlend : FuelBlendType;
        out h2Percentage : PercentageValue;
        out cngPercentage : PercentageValue;
    }

    action def ConfigureBlending {
        in h2Ratio : PercentageValue;
        in cngRatio : PercentageValue;
        out valveSettings : Real[2];
    }

    action def MonitorPressure {
        in currentPressure : PressureValue;
        in maxPressure : PressureValue;
        out pressureSafe : Boolean;
    }

    action def MonitorTemperature {
        in currentTemp : TemperatureValue;
        in maxTemp : TemperatureValue;
        out temperatureSafe : Boolean;
    }

    action def ControlFlowRate {
        in targetFlow : MassFlowRateValue;
        in currentFlow : MassFlowRateValue;
        out flowAdjustment : Real;
    }

    action def DispenseFuel {
        in targetAmount : MassValue;
        in blendType : FuelBlendType;
        out dispensedAmount : MassValue;
        out dispensingComplete : Boolean;
    }

    action def PerformSafetyCheck {
        in pressureStatus : Boolean;
        in temperatureStatus : Boolean;
        in leakStatus : Boolean;
        in nozzleConnected : Boolean;
        out safetyApproved : Boolean;
    }

    action def CompleteTransaction {
        in dispensedVolume : MassValue;
        in fuelType : FuelBlendType;
        in sessionId : String;
        out receipt : String;
    }

    action def EmergencyShutdown {
        in faultReason : String;
        out shutdownComplete : Boolean;
    }

    action def HCNGDispensingSequence {
        first start;
        then merge readyCheck;

        action readyCheck : PerformSafetyCheck {
            in pressureStatus;
            in temperatureStatus;
            in leakStatus;
            in nozzleConnected;
            out safetyApproved;
        }

        then decide;
            if readyCheck.safetyApproved then authenticate;
            if !readyCheck.safetyApproved then emergencyStop;

        action authenticate : AuthenticateUser {
            in userId;
            in paymentMethod;
            out authenticationResult;
            out sessionId;
        }

        then decide;
            if authenticate.authenticationResult then selectBlend;
            if !authenticate.authenticationResult then abortSession;

        action selectBlend : SelectFuelBlend {
            in requestedBlend;
            out h2Percentage;
            out cngPercentage;
        }

        then configureSystem;

        action configureSystem : ConfigureBlending {
            in h2Ratio = selectBlend.h2Percentage;
            in cngRatio = selectBlend.cngPercentage;
            out valveSettings;
        }

        then prepareDispensing;

        action prepareDispensing : MonitorPressure {
            in currentPressure;
            in maxPressure;
            out pressureSafe;
        }

        then decide;
            if prepareDispensing.pressureSafe then startDispensing;
            if !prepareDispensing.pressureSafe then emergencyStop;

        action startDispensing : DispenseFuel {
            in targetAmount;
            in blendType = selectBlend.requestedBlend;
            out dispensedAmount;
            out dispensingComplete;
        }

        then merge monitorLoop;

        action monitorLoop : ControlFlowRate {
            in targetFlow;
            in currentFlow;
            out flowAdjustment;
        }

        then decide;
            if !startDispensing.dispensingComplete then monitorLoop;
            if startDispensing.dispensingComplete then finalCheck;

        action finalCheck : PerformSafetyCheck {
            in pressureStatus;
            in temperatureStatus;
            in leakStatus;
            in nozzleConnected;
            out safetyApproved;
        }

        then decide;
            if finalCheck.safetyApproved then completeSession;
            if !finalCheck.safetyApproved then emergencyStop;

        action completeSession : CompleteTransaction {
            in dispensedVolume = startDispensing.dispensedAmount;
            in fuelType = selectBlend.requestedBlend;
            in sessionId = authenticate.sessionId;
            out receipt;
        }

        then done;

        action emergencyStop : EmergencyShutdown {
            in faultReason;
            out shutdownComplete;
        }

        then done;

        action abortSession {
            doc /* Cancel dispensing session due to authentication failure */
        }

        then done;
    }

    part def HCNGDispenser {
        attribute maxOperatingPressure : PressureValue;
        attribute maxFlowRate : MassFlowRateValue;
        attribute operationalState : DispenserStateKind;
        attribute totalDispensedToday : MassValue;

        part hydrogenStorage : StorageTank {
            attribute :>> capacity = 500.0;
            attribute :>> storagePressure = 350.0;
            attribute :>> storageTemperature = 288.15;
        }

        part cngStorage : StorageTank {
            attribute :>> capacity = 1200.0;
            attribute :>> storagePressure = 250.0;
            attribute :>> storageTemperature = 288.15;
        }

        part blendingValve : BlendingValve {
            attribute :>> hydrogenRatio = 20.0;
            attribute :>> cngRatio = 80.0;
            attribute :>> valvePosition = 0.0;
        }

        part compressionUnit : CompressionModule {
            attribute :>> targetPressure = 200.0;
            attribute :>> currentPressure = 0.0;
            attribute :>> compressionRatio = 1.5;
        }

        part mainPressureSensor : PressureSensor {
            attribute :>> measuredPressure = 0.0;
        }

        part mainTemperatureSensor : TemperatureSensor {
            attribute :>> measuredTemperature = 288.15;
        }

        part flowMeter : FlowMeter {
            attribute :>> measuredFlowRate = 0.0;
            attribute :>> totalDispensed = 0.0;
        }

        part nozzle : DispensingNozzle {
            attribute :>> isConnected = false;
            attribute :>> nozzlePressure = 0.0;
            attribute :>> lockEngaged = false;
        }

        part safetyValve : SafetyShutoffValve {
            attribute :>> isOpen = false;
            attribute :>> emergencyStop = false;
        }

        part leakDetector : LeakDetectionSystem {
            attribute :>> leakDetected = false;
            attribute :>> sensorCount = 4;
            attribute :>> alarmActive = false;
        }

        part controller : ControlModule {
            attribute :>> currentState = DispenserStateKind::idle;
            attribute :>> selectedBlend = FuelBlendType::hcng20;
            attribute :>> targetDispenseAmount = 0.0;
            attribute :>> dispensedAmount = 0.0;

            perform action dispensingOperation[*] ordered references HCNGDispensingSequence;
        }

        part userPanel : UserInterface {
            attribute :>> displayMessage = "System Ready";
            attribute :>> selectedFuelType = FuelBlendType::hcng20;
            attribute :>> authenticationStatus = false;
        }

        part ventSystem : VentingSystem {
            attribute :>> ventOpen = false;
            attribute :>> ventPressure = 0.0;
        }

        connection h2Supply connect hydrogenStorage.supplyPort to blendingValve.h2Input;
        connection cngSupply connect cngStorage.supplyPort to blendingValve.cngInput;
        connection blendedFuel connect blendingValve.mixedOutput to compressionUnit.gasInput;
        connection compressedFuel connect compressionUnit.compressedOutput to safetyValve.gasFlow;
        connection safeFuel connect safetyValve.safeOutput to nozzle.fuelInput;
        connection pressureMonitoring connect mainPressureSensor.pressureReading to controller.sensorInputs;
        connection temperatureMonitoring connect mainTemperatureSensor.temperatureReading to controller.sensorInputs;
        connection flowMonitoring connect flowMeter.flowReading to controller.sensorInputs;
        connection leakMonitoring connect leakDetector.alarmSignal to controller.sensorInputs;
        connection valveControl connect controller.valveControls to blendingValve;
        connection safetyControl connect controller.valveControls to safetyValve.controlSignal;
        connection userInput connect userPanel.userSelections to controller.userCommands;
        connection displayControl connect controller.displayOutputs to userPanel.statusUpdates;
        connection ventControl connect controller.valveControls to ventSystem.ventControl;
    }

    constraint def BlendRatioConstraint {
        in h2Percentage : PercentageValue;
        in cngPercentage : PercentageValue;
        h2Percentage + cngPercentage == 100.0
    }

    constraint def PressureSafetyConstraint {
        in operatingPressure : PressureValue;
        in maxPressure : PressureValue;
        operatingPressure <= maxPressure
    }

    constraint def FlowRateConstraint {
        in currentFlow : MassFlowRateValue;
        in maxFlow : MassFlowRateValue;
        currentFlow <= maxFlow
    }

    requirement <'REQ-HCNG-001'> primaryDispensingFunction {
        doc /* The HCNG dispenser shall safely dispense a precisely blended mixture 
             * of hydrogen and compressed natural gas to vehicles, with user-selectable 
             * blend ratios ranging from pure CNG to 30% hydrogen content, while 
             * maintaining continuous monitoring of pressure, temperature, flow rate, 
             * and leak detection to ensure safe operation throughout the dispensing cycle.
             */
        subject dispenser : HCNGDispenser;
    }

    requirement <'REQ-HCNG-002'> blendAccuracy {
        doc /* The dispenser shall maintain blend ratio accuracy within ±2% of the 
             * selected hydrogen percentage throughout the dispensing operation.
             */
        subject valve :>> HCNGDispenser::blendingValve;
        assert constraint blendRatio : BlendRatioConstraint {
            in h2Percentage = valve.hydrogenRatio;
            in cngPercentage = valve.cngRatio;
        }
    }

    requirement <'REQ-HCNG-003'> pressureSafety {
        doc /* The dispenser shall not exceed maximum operating pressure of 250 bar 
             * at any point in the fuel delivery path and shall automatically shut down 
             * if pressure exceeds 90% of maximum.
             */
        subject dispenser :>> hcngDispenserSystem;
        assert constraint pressureLimit : PressureSafetyConstraint {
            in operatingPressure = dispenser.mainPressureSensor.measuredPressure;
            in maxPressure = 250.0;
        }
    }

    requirement <'REQ-HCNG-004'> leakDetectionResponse {
        doc /* The leak detection system shall detect fuel leaks within 2 seconds 
             * and initiate emergency shutdown within 1 second of detection.
             */
        subject leakSystem :>> HCNGDispenser::leakDetector;
        assert constraint {
            leakSystem.leakDetected implies leakSystem.alarmActive
        }
    }

    requirement <'REQ-HCNG-005'> flowRateControl {
        doc /* The dispenser shall control fuel flow rate to not exceed 0.5 kg/s 
             * to ensure safe and controlled filling of vehicle tanks.
             */
        subject dispenser :>> hcngDispenserSystem;
        assert constraint flowLimit : FlowRateConstraint {
            in currentFlow = dispenser.flowMeter.measuredFlowRate;
            in maxFlow = 0.5;
        }
    }

    requirement <'REQ-HCNG-006'> userAuthentication {
        doc /* The dispenser shall require successful user authentication before 
             * allowing any dispensing operation to commence.
             */
        subject ctrl :>> HCNGDispenser::controller;
    }

    requirement <'REQ-HCNG-007'> nozzleConnection {
        doc /* The dispenser shall verify secure nozzle connection to vehicle 
             * before enabling fuel flow.
             */
        subject nozzle :>> HCNGDispenser::nozzle;
        assert constraint {
            nozzle.isConnected and nozzle.lockEngaged
        }
    }

    part hcngDispenserSystem : HCNGDispenser {
        attribute :>> maxOperatingPressure = 250.0;
        attribute :>> maxFlowRate = 0.5;
        attribute :>> operationalState = DispenserStateKind::idle;
        attribute :>> totalDispensedToday = 0.0;
    }

    satisfy primaryDispensingFunction by hcngDispenserSystem;
    satisfy blendAccuracy by hcngDispenserSystem.blendingValve;
    satisfy pressureSafety by hcngDispenserSystem;
    satisfy leakDetectionResponse by hcngDispenserSystem.leakDetector;
    satisfy flowRateControl by hcngDispenserSystem;
    satisfy userAuthentication by hcngDispenserSystem.controller;
    satisfy nozzleConnection by hcngDispenserSystem.nozzle;
}
