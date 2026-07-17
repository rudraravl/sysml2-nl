package ExtraVehicularActivitySystem {
    attribute def startPrebreathing;
    attribute def beginDepressurization;
    attribute def egressComplete;
    attribute def initiateReturn;
    attribute def ingressComplete;
    attribute def repressurizationComplete;

    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def PressureValue :> ISQ::pressure;
    attribute def VolumeValue :> ISQ::volume;
    attribute def MassValue :> ISQ::mass;
    attribute def PowerValue :> ISQ::power;
    attribute def TemperatureValue :> ISQ::thermodynamicTemperature;
    attribute def DurationValue :> ISQ::duration;
    attribute def FlowRateValue :> Real;
    
    enum def EVAPhase {
        prebreathing;
        depressurization;
        egress;
        operations;
        ingress;
        repressurization;
    }
    
    enum def SystemStatus {
        nominal;
        degraded;
        critical;
        failed;
    }
    
    item def Oxygen;
    item def CarbonDioxide;
    item def Water;
    item def ElectricalPower;
    item def CommunicationSignal;
    
    port def GasPort {
        attribute flowRate : FlowRateValue;
        attribute pressure : PressureValue;
    }
    
    port def PowerPort {
        attribute voltage : Real;
        attribute current : Real;
    }
    
    port def DataPort {
        attribute bandwidth : Real;
        attribute signalStrength : Real;
    }
    
    port def TetherPort {
        attribute tension : Real;
        attribute isConnected : Boolean;
    }
    
    part def PrimaryLifeSupportSubsystem {
        attribute oxygenCapacity : VolumeValue;
        attribute oxygenRemaining : VolumeValue;
        attribute batteryCapacity : PowerValue;
        attribute batteryRemaining : PowerValue;
        attribute waterCapacity : VolumeValue;
        attribute waterRemaining : VolumeValue;
        
        port oxygenOut : GasPort;
        port co2In : GasPort;
        port powerOut : PowerPort;
        port coolantFlow : GasPort;
        
        part oxygenTank {
            attribute capacity : VolumeValue;
            attribute currentLevel : VolumeValue;
        }
        
        part co2RemovalSystem {
            attribute removalRate : FlowRateValue;
            attribute filterSaturation : Real;
        }
        
        part battery {
            attribute capacity : PowerValue;
            attribute chargeLevel : Real;
        }
        
        part waterCoolingSystem {
            attribute flowRate : FlowRateValue;
            attribute temperature : TemperatureValue;
        }
    }
    
    part def PressureGarmentAssembly {
        attribute internalPressure : PressureValue;
        attribute targetPressure : PressureValue;
        attribute layerCount : Integer;
        
        port gasSupply : GasPort;
        port wasteGas : GasPort;
        port powerIn : PowerPort;
        
        part pressureLayer {
            attribute material : String;
            attribute thickness : Real;
        }
        
        part restraintLayer {
            attribute material : String;
            attribute tensileStrength : Real;
        }
        
        part thermalMicrometeoroidGarment {
            attribute layers : Integer;
            attribute thermalResistance : Real;
        }
    }
    
    part def HelmetAndVisorAssembly {
        attribute visorPosition : Real;
        attribute internalPressure : PressureValue;
        
        part polycarbonateShell {
            attribute thickness : Real;
            attribute impactResistance : Real;
        }
        
        part goldVisor {
            attribute solarReflectance : Real;
            attribute isDeployed : Boolean;
        }
        
        part ventilationSystem {
            attribute flowRate : FlowRateValue;
        }
    }
    
    part def ExtravehicularGloves {
        attribute fingerDexterity : Real;
        attribute gripStrength : Real;
        attribute heaterPower : PowerValue;
        
        port powerIn : PowerPort;
    }
    
    part def CommunicationCarrierAssembly {
        attribute transmitPower : PowerValue;
        attribute receiveFrequency : Real;
        attribute transmitFrequency : Real;
        
        port dataLink : DataPort;
        port powerIn : PowerPort;
        
        part microphone {
            attribute sensitivity : Real;
        }
        
        part speaker {
            attribute volume : Real;
        }
        
        part radioTransceiver {
            attribute range : Real;
        }
    }
    
    part def DisplayAndControlModule {
        attribute displayBrightness : Real;
        
        port powerIn : PowerPort;
        port dataIn : DataPort;
        
        part statusDisplay {
            attribute oxygenLevel : Real;
            attribute pressureReading : PressureValue;
            attribute batteryLevel : Real;
        }
        
        part controlInterface {
            attribute temperatureControl : Real;
            attribute ventilationControl : Real;
        }
    }
    
    part def SafetyTether {
        attribute length : Real;
        attribute tensileStrength : Real;
        attribute isAttached : Boolean;
        
        port vehicleEnd : TetherPort;
        port suitEnd : TetherPort;
    }
    
    part def SimplifiedAidForEVARescue {
        attribute propellantMass : MassValue;
        attribute deltaV : Real;
        attribute thrusterCount : Integer;
        
        port powerIn : PowerPort;
        
        part nitrogenTank {
            attribute pressure : PressureValue;
            attribute volume : VolumeValue;
        }
        
        part thrusterArray {
            attribute thrust : Real;
        }
    }
    
    part def Spacecraft {
        attribute airlockPressure : PressureValue;
        
        port airlockInterface;
        port tetherAnchor : TetherPort;
        port commRelay : DataPort;
        port powerSupply : PowerPort;
    }
    
    part def ExtravehicularMobilityUnit {
        attribute totalMass : MassValue;
        attribute operationalDuration : DurationValue;
        attribute suitPressure : PressureValue;
        attribute currentPhase : EVAPhase;
        attribute systemStatus : SystemStatus;
        
        part plss : PrimaryLifeSupportSubsystem;
        
        part pressureGarment : PressureGarmentAssembly;
        
        part helmet : HelmetAndVisorAssembly;
        
        part gloves : ExtravehicularGloves;
        
        part commSystem : CommunicationCarrierAssembly;
        
        part displayControl : DisplayAndControlModule;
        
        part safer : SimplifiedAidForEVARescue;
        
        connection plssToGarment connect plss.oxygenOut to pressureGarment.gasSupply;
        
        connection garmentToPlss connect pressureGarment.wasteGas to plss.co2In;
        
        connection plssPower connect plss.powerOut to pressureGarment.powerIn;
        
        connection commPower connect plss.powerOut to commSystem.powerIn;
        
        connection displayPower connect plss.powerOut to displayControl.powerIn;
        
        connection saferPower connect plss.powerOut to safer.powerIn;
        
        connection glovePower connect plss.powerOut to gloves.powerIn;
        
        connection commToDisplay connect commSystem.dataLink to displayControl.dataIn;
    }
    
    part def EVACrewMember {
        attribute metabolicRate : PowerValue;
        attribute oxygenConsumption : FlowRateValue;
        attribute co2Production : FlowRateValue;
        attribute experienceLevel : String;
    }
    
    action def MonitorLifeSupport {
        in oxygenLevel : VolumeValue;
        in batteryLevel : PowerValue;
        in suitPressure : PressureValue;
        out status : SystemStatus;
    }
    
    action def RegulateEnvironment {
        in targetPressure : PressureValue;
        in currentPressure : PressureValue;
        in targetTemperature : TemperatureValue;
        in currentTemperature : TemperatureValue;
        out pressureAdjustment : Real;
        out thermalAdjustment : Real;
    }
    
    action def PerformEVAOperations {
        in emu : ExtravehicularMobilityUnit;
        in crew : EVACrewMember;
        in missionDuration : DurationValue;
        
        first start;
        
        then action prebreathe {
            doc /* Crew member breathes pure oxygen for 4 hours to eliminate nitrogen */
        }
        
        then action depressurizeAirlock {
            doc /* Reduce airlock pressure from 101 kPa to vacuum */
        }
        
        then action egressSpacecraft {
            doc /* Exit through airlock to external environment */
        }
        
        then merge operationLoop;
        
        then action monitor : MonitorLifeSupport {
            in oxygenLevel;
            in batteryLevel;
            in suitPressure;
            out status : SystemStatus;
        }
        
        then decide;
            if monitor.status == SystemStatus::critical then emergencyReturn;
            else performTask;
        
        action performTask {
            doc /* Execute assigned EVA task */
        }
        then operationLoop;
        
        action emergencyReturn {
            doc /* Immediate return to spacecraft */
        }
        then ingressSpacecraft;
        
        action ingressSpacecraft {
            doc /* Return through airlock */
        }
        
        then action repressurizeAirlock {
            doc /* Restore airlock to cabin pressure */
        }
        
        then action postEVAInspection {
            doc /* Inspect suit for damage and contamination */
        }
        
        then done;
    }
    
    state def EVASystemStateMachine {
        entry; then standby;
        
        state standby;
        
        transition standby_to_prebreathing
            first standby
            accept startPrebreathing
            then prebreathing;
        
        state prebreathing;
        
        transition prebreathing_to_depressurizing
            first prebreathing
            accept beginDepressurization
            then depressurizing;
        
        state depressurizing;
        
        transition depressurizing_to_active
            first depressurizing
            accept egressComplete
            then active;
        
        state active {
            entry; then monitoring;
            
            state monitoring;
            state executing;
        }
        
        transition active_to_returning
            first active
            accept initiateReturn
            then returning;
        
        state returning;
        
        transition returning_to_repressurizing
            first returning
            accept ingressComplete
            then repressurizing;
        
        state repressurizing;
        
        transition repressurizing_to_standby
            first repressurizing
            accept repressurizationComplete
            then standby;
    }
    
    requirement def OperationalDurationRequirement {
        doc /* The EVA system shall support continuous operation for specified duration */
        subject emu : ExtravehicularMobilityUnit;
        in requiredDuration : DurationValue;
        require constraint {
            emu.operationalDuration >= requiredDuration
        }
    }
    
    requirement def OxygenSupplyRequirement {
        doc /* The PLSS shall provide sufficient oxygen for mission plus reserve */
        subject plss : PrimaryLifeSupportSubsystem;
        in missionDuration : DurationValue;
        in consumptionRate : FlowRateValue;
        in reserveMargin : Real;
    }
    
    requirement def PressureMaintenanceRequirement {
        doc /* The suit shall maintain pressure within safe operational limits */
        subject emu : ExtravehicularMobilityUnit;
        in minPressure : PressureValue;
        in maxPressure : PressureValue;
        require constraint {
            emu.suitPressure >= minPressure and emu.suitPressure <= maxPressure
        }
    }
    
    requirement def MassLimitRequirement {
        doc /* The total EMU mass shall not exceed specified maximum */
        subject emu : ExtravehicularMobilityUnit;
        in maxMass : MassValue;
        require constraint {
            emu.totalMass <= maxMass
        }
    }
    
    requirement <'EVA-SYS-001'> primaryMissionRequirement {
        doc /* The Extra-vehicular Activity system shall enable astronauts to safely exit 
             * a spacecraft and perform work in the space environment by providing life support,
             * environmental protection, mobility, communication, and emergency capabilities
             * for extended duration operations in vacuum conditions.
             */
        subject evaSystem : ExtravehicularMobilityUnit;
    }
    
    part evaSystem : ExtravehicularMobilityUnit {
        perform action evaOps : PerformEVAOperations;
    }
    
    item crewMember : EVACrewMember;
    
    part spacecraft : Spacecraft;
    
    part tether : SafetyTether;
    
    connection tetherToSpacecraft connect tether.vehicleEnd to spacecraft.tetherAnchor;
    
    satisfy primaryMissionRequirement by evaSystem;
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import ExtraVehicularActivitySystem::*;

    part testSubject : PrimaryLifeSupportSubsystem {
        exhibit state sm : EVASystemStateMachine;
    }

    action orchestrator {
        attribute testOxygenLevel : VolumeValue;
        attribute testBatteryLevel : PowerValue;
        attribute testSuitPressure : PressureValue;
        action actionProbe : MonitorLifeSupport {
            in oxygenLevel = testOxygenLevel;
            in batteryLevel = testBatteryLevel;
            in suitPressure = testSuitPressure;
        }
        attribute testStartPrebreathing : startPrebreathing;
        attribute testBeginDepressurization : beginDepressurization;
        attribute testEgressComplete : egressComplete;
        attribute testInitiateReturn : initiateReturn;
        attribute testIngressComplete : ingressComplete;
        attribute testRepressurizationComplete : repressurizationComplete;
        action triggerstartPrebreathing send testStartPrebreathing to testSubject;
        action triggerbeginDepressurization send testBeginDepressurization to testSubject;
        action triggeregressComplete send testEgressComplete to testSubject;
        action triggerinitiateReturn send testInitiateReturn to testSubject;
        action triggeringressComplete send testIngressComplete to testSubject;
        action triggerrepressurizationComplete send testRepressurizationComplete to testSubject;
        first actionProbe;
        then triggerstartPrebreathing;
        then triggerbeginDepressurization;
        then triggeregressComplete;
        then triggerinitiateReturn;
        then triggeringressComplete;
        then triggerrepressurizationComplete;
    }
}
