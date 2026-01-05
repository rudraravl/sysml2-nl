package MiraDryMedicalSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    attribute def MicrowaveFrequency :> ISQ::FrequencyValue;
    attribute def TreatmentPower :> ISQ::PowerValue;
    attribute def TreatmentDuration :> ISQ::DurationValue;
    attribute def SkinTemperature :> ISQ::ThermodynamicTemperatureValue;
    attribute def TissueDepth :> ISQ::LengthValue;
    attribute def VacuumPressure :> ISQ::PressureValue;
    attribute def CoolantTemperature :> ISQ::ThermodynamicTemperatureValue;
    attribute def EnergyDose :> ISQ::EnergyValue;

    item def TreatmentCommand {
        attribute powerLevel : TreatmentPower;
        attribute duration : TreatmentDuration;
        attribute targetDepth : TissueDepth;
    }

    item def SensorData {
        attribute surfaceTemp : SkinTemperature;
        attribute tissueTemp : SkinTemperature;
        attribute vacuumLevel : VacuumPressure;
        attribute contactDetected : Boolean;
    }

    item def CoolantFlow {
        attribute temperature : CoolantTemperature;
        attribute flowRate : ISQ::VolumeFlowRateValue;
    }

    port def EnergyDeliveryPort {
        out microwaveEnergy : TreatmentPower;
        in temperatureFeedback : SkinTemperature;
    }

    port def CoolingInterfacePort {
        in coolantSupply : CoolantFlow;
        out coolantReturn : CoolantFlow;
    }

    port def ControlInterfacePort {
        in commands : TreatmentCommand;
        out sensorReadings : SensorData;
    }

    port def VacuumPort {
        out vacuumPressure : VacuumPressure;
        in tissuePosition : TissueDepth;
    }

    part def ConsoleUnit {
        doc /* Main control console containing power supply, user interface, and control electronics. */
        
        attribute operatingVoltage : ISQ::ElectricPotentialValue;
        attribute maxOutputPower : TreatmentPower;
        
        port controlInterface : ControlInterfacePort;
        port powerOutput : EnergyDeliveryPort;
        port coolantInterface : CoolingInterfacePort;
        
        part powerSupply {
            attribute inputVoltage : ISQ::ElectricPotentialValue = 120.0[SI::V];
            attribute outputPower : TreatmentPower = 60.0[SI::W];
        }
        
        part userInterface {
            attribute displayType : String;
            perform action displayStatus;
            perform action acceptInput;
        }
        
        part controlProcessor {
            perform action processCommands;
            perform action monitorSafety;
        }
        
        part coolantReservoir {
            attribute capacity : ISQ::VolumeValue = 2.0[SI::L];
            attribute currentLevel : ISQ::VolumeValue;
        }
        
        exhibit state machine consoleStates;
    }

    part def HandpieceAssembly {
        doc /* Handheld applicator containing microwave antenna, cooling system, and vacuum mechanism. */
        
        port energyInput : EnergyDeliveryPort;
        port coolingInput : CoolingInterfacePort;
        port vacuumInterface : VacuumPort;
        port sensorOutput : ControlInterfacePort;
        
        part microwaveAntenna {
            attribute frequency : MicrowaveFrequency = 5.8e9[SI::Hz];
            attribute antennaType : String = "Dipole Array";
            perform action emitMicrowaveEnergy;
        }
        
        part coolingPlate {
            attribute plateTemperature : CoolantTemperature;
            perform action transferHeat;
        }
        
        part vacuumChamber {
            attribute chamberPressure : VacuumPressure;
            perform action createVacuum;
            perform action positionTissue;
        }
        
        part temperatureSensors {
            attribute surfaceSensor : SkinTemperature;
            attribute deepSensor : SkinTemperature;
            perform action measureTemperature;
        }
        
        part contactSensor {
            attribute contactStatus : Boolean;
            perform action detectContact;
        }
    }

    part def BioTipApplicator {
        doc /* Disposable single-use applicator tip that interfaces with patient skin. */
        
        attribute tipSize : String;
        attribute usageCount : Integer = 0;
        attribute maxUsage : Integer = 1;
        
        port tissueInterface;
        port handpieceConnection;
        
        part ceramicWindow {
            attribute microwaveTransmission : Real = 0.95;
        }
        
        part coolingSurface {
            attribute thermalConductivity : ISQ::ThermalConductivityValue;
        }
        
        part vacuumSeal {
            attribute sealIntegrity : Boolean;
        }
    }

    action def InitializeSystem {
        out systemReady : Boolean;
        
        first start;
        then action performSelfTest {
            out testPassed : Boolean;
        }
        then action primeFluidSystem {
            out fluidReady : Boolean;
        }
        then action calibrateSensors {
            out sensorsCalibrated : Boolean;
        }
        then decide;
            if performSelfTest.testPassed and primeFluidSystem.fluidReady 
               and calibrateSensors.sensorsCalibrated then ready;
            if not (performSelfTest.testPassed and primeFluidSystem.fluidReady 
               and calibrateSensors.sensorsCalibrated) then fault;
        action ready {
            assign systemReady := true;
        }
        then done;
        action fault {
            assign systemReady := false;
        }
        then done;
    }

    action def ApplyVacuumAndCooling {
        in targetVacuum : VacuumPressure;
        in targetCoolantTemp : CoolantTemperature;
        out tissueStabilized : Boolean;
        out coolingActive : Boolean;
        
        first start;
        then action activateVacuum {
            out vacuumAchieved : Boolean;
        }
        then action startCoolant {
            out coolantFlowing : Boolean;
        }
        then action waitForStabilization {
            out stabilized : Boolean;
        }
        then assign tissueStabilized := waitForStabilization.stabilized;
        then assign coolingActive := startCoolant.coolantFlowing;
        then done;
    }

    action def DeliverMicrowaveEnergy {
        in powerSetting : TreatmentPower;
        in duration : TreatmentDuration;
        in depthTarget : TissueDepth;
        out energyDelivered : EnergyDose;
        out maxTempReached : SkinTemperature;
        
        private attribute elapsedTime : TreatmentDuration := 0.0[SI::s];
        private attribute accumulatedEnergy : EnergyDose := 0.0[SI::J];
        private attribute currentTemp : SkinTemperature := 305.15[SI::K];
        
        first start;
        then merge energyLoop;
        then action monitorTemperature {
            out measuredTemp : SkinTemperature;
        }
        then action checkSafetyLimits {
            in temperature = monitorTemperature.measuredTemp;
            out withinLimits : Boolean;
        }
        then decide;
            if checkSafetyLimits.withinLimits and elapsedTime < duration then emitEnergy;
            if not checkSafetyLimits.withinLimits then emergencyShutdown;
            if elapsedTime >= duration then completeTreatment;
        action emitEnergy {
            action applyPower {
                out powerApplied : TreatmentPower;
            }
            then assign accumulatedEnergy := accumulatedEnergy + applyPower.powerApplied * 0.1[SI::s];
            then assign elapsedTime := elapsedTime + 0.1[SI::s];
            then assign currentTemp := monitorTemperature.measuredTemp;
        }
        then energyLoop;
        action emergencyShutdown {
            assign energyDelivered := accumulatedEnergy;
            assign maxTempReached := currentTemp;
        }
        then done;
        action completeTreatment {
            assign energyDelivered := accumulatedEnergy;
            assign maxTempReached := currentTemp;
        }
        then done;
    }

    action def PerformTreatmentCycle {
        in treatmentZone : Integer;
        in prescribedDose : EnergyDose;
        out cycleComplete : Boolean;
        out actualDose : EnergyDose;
        
        first start;
        then action prepareApplicator : ApplyVacuumAndCooling {
            in targetVacuum = -50.0[SI::kPa];
            in targetCoolantTemp = 288.15[SI::K];
            out tissueStabilized;
            out coolingActive;
        }
        then decide;
            if prepareApplicator.tissueStabilized and prepareApplicator.coolingActive then deliverTreatment;
            if not (prepareApplicator.tissueStabilized and prepareApplicator.coolingActive) then abortCycle;
        action deliverTreatment {
            action applyEnergy : DeliverMicrowaveEnergy {
                in powerSetting = 50.0[SI::W];
                in duration = 30.0[SI::s];
                in depthTarget = 3.0[SI::mm];
                out energyDelivered;
                out maxTempReached;
            }
            then assign actualDose := applyEnergy.energyDelivered;
        }
        then action coolDown {
            out coolingComplete : Boolean;
        }
        then action releaseVacuum {
            out vacuumReleased : Boolean;
        }
        then assign cycleComplete := true;
        then done;
        action abortCycle {
            assign cycleComplete := false;
            assign actualDose := 0.0[SI::J];
        }
        then done;
    }

    state def ConsoleStateMachine {
        entry; then PowerOff;
        
        state PowerOff;
        
        state Initializing {
            entry action performInitialization : InitializeSystem;
        }
        
        state Ready {
            entry action displayReadyStatus;
        }
        
        state TreatmentActive {
            entry action beginTreatment;
            do action monitorTreatment;
            exit action endTreatment;
        }
        
        state Cooling {
            do action maintainCooling;
        }
        
        state Fault {
            entry action logFault;
            do action displayError;
        }
        
        transition powerOn first PowerOff then Initializing;
        
        transition initSuccess first Initializing then Ready;
        
        transition initFail first Initializing then Fault;
        
        transition startTreatment first Ready then TreatmentActive;
        
        transition treatmentComplete first TreatmentActive then Cooling;
        
        transition treatmentFault first TreatmentActive then Fault;
        
        transition cooldownComplete first Cooling then Ready;
        
        transition faultRecovery first Fault then Initializing;
        
        transition shutdown first Ready then PowerOff;
    }

    part def MiraDrySystem {
        doc /* 
            The miraDry system is a non-invasive medical device that permanently 
            reduces underarm sweat, odor, and hair by delivering precisely controlled 
            electromagnetic energy to the dermal-hypodermal junction where sweat glands 
            and hair follicles reside. The system uses microwave energy at 5.8 GHz 
            to thermally ablate eccrine and apocrine sweat glands while simultaneously 
            protecting the epidermis and upper dermis through continuous hydro-ceramic 
            cooling and vacuum-assisted tissue positioning.
        */
        
        attribute systemSerialNumber : String;
        attribute softwareVersion : String;
        attribute operatingFrequency : MicrowaveFrequency = 5.8e9[SI::Hz];
        attribute maxPowerOutput : TreatmentPower = 60.0[SI::W];
        attribute treatmentDepthRange : TissueDepth[2] = (2.0[SI::mm], 5.0[SI::mm]);
        
        part console : ConsoleUnit {
            attribute :>> operatingVoltage = 120.0[SI::V];
            attribute :>> maxOutputPower = 60.0[SI::W];
        }
        
        part handpiece : HandpieceAssembly;
        
        part bioTip : BioTipApplicator {
            attribute :>> tipSize = "Standard";
        }
        
        connection energyDelivery connect console.powerOutput to handpiece.energyInput;
        connection coolingSystem connect console.coolantInterface to handpiece.coolingInput;
        connection controlLink connect console.controlInterface to handpiece.sensorOutput;
        connection applicatorInterface connect handpiece to bioTip.handpieceConnection;
        
        perform action systemOperation : PerformTreatmentCycle {
            in treatmentZone = 1;
            in prescribedDose = 1500.0[SI::J];
            out cycleComplete;
            out actualDose;
        }
    }

    requirement <'REQ-001'> primaryFunctionRequirement {
        doc /* 
            The miraDry system shall permanently reduce underarm perspiration 
            by delivering controlled electromagnetic energy to eliminate sweat 
            glands at the dermal-hypodermal interface while maintaining skin 
            surface temperature within safe limits through active cooling.
        */
        
        subject miraDrySystem : MiraDrySystem;
        
        require constraint energyPrecision {
            doc /* Energy shall be delivered to target depth with spatial precision. */
            miraDrySystem.treatmentDepthRange#(1) >= 2.0[SI::mm] and 
            miraDrySystem.treatmentDepthRange#(2) <= 5.0[SI::mm]
        }
        
        require constraint frequencySpecification {
            doc /* System shall operate at FDA-cleared frequency. */
            miraDrySystem.operatingFrequency == 5.8e9[SI::Hz]
        }
    }

    requirement <'REQ-002'> thermalSafetyRequirement {
        doc /* 
            The system shall maintain epidermal temperature below 45°C during 
            energy delivery through continuous cooling to prevent thermal injury.
        */
        
        subject miraDrySystem : MiraDrySystem;
        
        require constraint surfaceTemperatureLimit {
            doc /* Surface temperature must remain below thermal injury threshold. */
        }
        
        require constraint continuousCooling {
            doc /* Cooling must be active during all energy delivery phases. */
        }
    }

    requirement <'REQ-003'> treatmentEfficacyRequirement {
        doc /* 
            The system shall deliver sufficient energy dose to achieve therapeutic 
            temperature (58-62°C) at target tissue depth for sweat gland thermolysis.
        */
        
        subject miraDrySystem : MiraDrySystem;
        
        require constraint therapeuticTemperature {
            doc /* Target tissue shall reach temperature sufficient for gland ablation. */
        }
        
        require constraint doseAccuracy {
            doc /* Delivered energy dose shall be within ±10% of prescribed value. */
        }
    }

    part miraDryDevice : MiraDrySystem {
        attribute :>> systemSerialNumber = "MD-2024-001";
        attribute :>> softwareVersion = "v3.2.1";
        
        satisfy primaryFunctionRequirement;
        satisfy thermalSafetyRequirement;
        satisfy treatmentEfficacyRequirement;
    }
}
