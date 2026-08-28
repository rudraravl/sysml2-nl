package EVA_System {
    import ISQ::*;
    import ScalarFunctions::*;

    // ===== Value Types =====
    value type PressureValue :> Real { unit 'Pa'; }
    value type TemperatureValue :> Real { unit 'K'; }
    value type MassValue :> Real {> Real { unit 'kg'; }
    value type VolumeFlowRate :> Real { unit 'm3/s'; }
    value type ElectricPotentialValue :> Real { unit 'V'; }
    value type ElectricChargeValue :> Real { unit 'C'; }
    value type EnergyValue :> Real { unit 'J'; }
    value type PowerValue :> Real { unit 'W'; }
    value type DurationValue :> Real { unit 's'; }
    value type ForceValue :> Real { unit 'N'; }
    value type VelocityValue :> Real { unit 'm/s'; }
    value type MassFraction :> Real { unit '1'; }
    value type Dimensionless :> Real { unit '1'; }

    // ===== Item Types =====
    item def Oxygen {
        attribute pressure : PressureValue;
        attribute temperature : TemperatureValue;
    }
    item def CarbonDioxide {
        attribute partialPressure : PressureValue;
    }
    item def CoolantFluid {
        attribute temperature : TemperatureValue;
        attribute flowRate : VolumeFlowRate;
    }
    item def NitrogenGas {
        attribute pressure : PressureValue;
        attribute mass : MassValue;
    }
    item def ElectricalPower {
        attribute voltage : ElectricPotentialValue;
        attribute charge : ElectricChargeValue;
    }
    item def VoiceSignal {
        attribute frequency : Real;
        attribute amplitude : Real;
    }
    item def TelemetryData {
        attribute oxygenLevel : MassFraction;
        attribute batteryLevel : MassFraction;
        attribute suitPressure : PressureValue;
        attribute coolantTemp : TemperatureValue;
    }
    item def ControlCommand {
        attribute targetTemperature : TemperatureValue;
        attribute fanSpeed : Dimensionless;
    }
    item def SpaceEnvironment {
        attribute ambientPressure : PressureValue;
        attribute ambientTemperature : TemperatureValue;
        attribute solarRadiationFlux : Real;
    }

    // ===== Enumerations =====
    enum def SystemStatus { nominal; degraded; critical; }
    enum def SuitOperationalState { standby; preparation; active; emergency; shutdown; }
    enum def EVAPhase { prebreathing; depressurization; egress; operations; ingress; repressurization; }

    // ===== Port Definitions =====
    port def OxygenPort {
        out oxygenOut : Oxygen;
        in oxygenIn : Oxygen;
    }
    port def CO2Port {
        in co2In : CarbonDioxide;
    }
    port def CoolantPort {
        out coolantOut : CoolantFluid;
        in coolantReturn : CoolantFluid;
    }
    port def PowerPort {
        out powerOut : ElectricalPower;
    }
    port def VoicePort {
        in voiceIn : VoiceSignal;
        out voiceOut : VoiceSignal;
    }
    port def DataPort {
        out telemetryOut : TelemetryData;
        in commandIn : ControlCommand;
    }
    port def ThrustPort {
        out thrustForce : ForceValue;
    }
    port def TetherPort {
        out tetherForce : ForceValue;
    }
    port def EnvironmentPort {
        in environment : SpaceEnvironment;
    }

    // ===== Requirements =====
    requirement def LifeSupportRequirement {
        attribute minOxygenPressure : PressureValue = 20.7e3;
        attribute maxCO2PartialPressure : PressureValue = 1.0e3;
        subject oxygenSupply : Oxygen;
        subject co2Removal : CarbonDioxide;
        require oxygenSupply.pressure >= minOxygenPressure
        and co2Removal.partialPressure <= maxCO2PartialPressure;
    }

    requirement def ThermalControlRequirement {
        attribute minCoolantTemp : TemperatureValue = 278.0;
        attribute maxCoolantTemp : TemperatureValue = 305.0;
        subject coolant : CoolantFluid;
        require coolant.temperature >= minCoolantTemp
        and coolant.temperature <= maxCoolantTemp;
    }

    requirement def PowerRequirement {
        attribute minBatteryVoltage : ElectricPotentialValue = 16.0;
        attribute minMissionDuration : DurationValue = 25200.0;
        subject power : ElectricalPower;
        require power.voltage >= minBatteryVoltage;
    }

    requirement def PressureGarmentRequirement {
        attribute suitPressure : PressureValue = 29.6e3;
        attribute tolerance : PressureValue = 1.0e3;
        subject suit : PressureGarmentAssembly;
        require suit.internalPressure >= suitPressure - tolerance
        and suit.internalPressure <= suitPressure + tolerance;
    }

    requirement def SAFERRequirement {
        attribute minDeltaV : VelocityValue = 3.0;
        subject safer : SAFER;
        require safer.availableDeltaV >= minDeltaV;
    }

    requirement def CommunicationRequirement {
        subject comm : CommunicationCarrierAssembly;
        require comm.transceiver.isOperational == true;
    }

    // ===== Component Definitions =====

    part def OxygenTank {
        attribute capacity : VolumeValue = 0.0012;
        attribute currentPressure : PressureValue;
        port oxygenOut : OxygenPort;
        action def SupplyOxygen {
            out oxygen : Oxygen;
        }
        perform SupplyOxygen {
            out oxygen = Oxygen { pressure = currentPressure; temperature = 293.0; };
        }
        satisfy LifeSupportRequirement by oxygenSupply;
    }

    part def CO2Filter {
        attribute absorptionCapacity : MassValue = 0.5;
        attribute currentLoad : MassValue;
        port co2In : CO2Port;
        action def RemoveCO2 {
            in co2 : CarbonDioxide;
            out filteredOxygen : Oxygen;
        }
        perform RemoveCO2;
        satisfy LifeSupportRequirement by co2Removal;
    }

    part def Battery {
        attribute capacity : ElectricChargeValue = 90000.0;
        attribute currentCharge : ElectricChargeValue;
        attribute voltage : ElectricPotentialValue;
        port powerOut : PowerPort;
        action def SupplyPower {
            out power : ElectricalPower;
        }
        perform SupplyPower {
            out power = ElectricalPower { voltage = voltage; charge = currentCharge; };
        }
        satisfy PowerRequirement by power;
    }

    part def CoolingSystem {
        attribute pumpFlowRate : VolumeFlowRate = 0.0001;
        attribute setpointTemperature : TemperatureValue = 291.0;
        port coolantOut : CoolantPort;
        port coolantReturn : CoolantPort;
        action def CirculateCoolant {
            in returnFluid : CoolantFluid;
            out supplyFluid : CoolantFluid;
        }
        perform CirculateCoolant {
            out supplyFluid = CoolantFluid { temperature = setpointTemperature; flowRate = pumpFlowRate; };
        }
        satisfy ThermalControlRequirement by coolant;
    }

    part def PrimaryLifeSupportSubsystem {
        attribute totalMass : MassValue = 65.0;
        attribute operationalPressure : PressureValue = 29.6e3;
        port oxygenSupply : OxygenPort;
        port co2Extraction : CO2Port;
        port powerSupply : PowerPort;
        port coolantSupply : CoolantPort;
        port coolantReturn : CoolantPort;

        part oxygenTank : OxygenTank {
            port redefines oxygenSupply;
        }
        part co2Filter : CO2Filter {
            port redefines co2Extraction;
        }
        part battery : Battery {
            port redefines powerSupply;
        }
        part coolingSystem : CoolingSystem {
            port redefines coolantSupply;
            port redefines coolantReturn;
        }

        connection oxygenTank.oxygenOut to co2Filter.co2In;
        connection coolingSystem.coolantOut to coolingSystem.coolantReturn;

        satisfy LifeSupportRequirement;
        satisfy PowerRequirement;
        satisfy ThermalControlRequirement;
    }

    part def PressureLayer {
        attribute material : String = "urethane-coated nylon";
        attribute maxPressure : PressureValue = 50.0e3;
    }
    part def RestraintLayer {
        attribute material : String = "Dacron";
        attribute tensileStrength : ForceValue = 5000.0;
    }
    part def ThermalMicrometeoroidGarment {
        attribute material : String = "Ortho-Fabric";
        attribute insulationValue : Real = 0.05;
        attribute micrometeoroidResistance : ForceValue = 100.0;
        port environmentIn : EnvironmentPort;
    }

    part def PressureGarmentAssembly {
        attribute internalPressure : PressureValue = 29.6e3;
        attribute internalTemperature : TemperatureValue = 293.0;
        port oxygenIn : OxygenPort;
        port oxygenOut : OxygenPort;
        port co2Out : CO2Port;
        port coolantIn : CoolantPort;
        port coolantOut : CoolantPort;
        port environmentPort : EnvironmentPort;

        part pressureLayer : PressureLayer;
        part restraintLayer : RestraintLayer;
        part tmg : ThermalMicrometeoroidGarment {
            port redefines environmentPort;
        }

        satisfy PressureGarmentRequirement by suit;
    }

    part def HelmetVisorAssembly {
        attribute shellMaterial : String = "polycarbonate";
        attribute visorCoating : String = "gold";
        attribute solarReflectivity : Real = 0.7;
        port oxygenIn : OxygenPort;
        port oxygenOut : OxygenPort;
        port environmentPort : EnvironmentPort;

        action def VentilateHelmet {
            in oxygenSupply : Oxygen;
            out circulatedOxygen : Oxygen;
        }
        perform VentilateHelmet;
    }

    part def ExtravehicularGloves {
        attribute heaterPower : PowerValue = 5.0;
        attribute heaterActive : Boolean = false;
        attribute dexterityRating : Real = 0.8;
        port powerIn : PowerPort;
        port oxygenIn : OxygenPort;

        action def RegulateHandTemperature {
            in command : ControlCommand;
            out heaterState : Boolean;
        }
        perform RegulateHandTemperature {
            out heaterState = heaterActive;
        }
    }

    part def RadioTransceiver {
        attribute frequency : Real = 415.0e6;
        attribute isOperational : Boolean = true;
        attribute range : Real = 100000.0;
        port voiceIn : VoicePort;
        port voiceOut : VoicePort;
    }

    part def CommunicationCarrierAssembly {
        attribute capType : String = "Snoopy";
        port voiceOut : VoicePort;
        port voiceIn : VoicePort;
        port radioLink : VoicePort;

        part microphone {
            port redefines voiceOut;
        }
        part speaker {
            port redefines voiceIn;
        }
        part transceiver : RadioTransceiver {
            port redefines radioLink;
        }

        connection microphone.voiceOut to transceiver.voiceIn;
        connection transceiver.voiceOut to speaker.voiceIn;

        satisfy CommunicationRequirement by comm;
    }

    part def DisplayAndControlModule {
        attribute displayType : String = "LCD";
        attribute backlight : Boolean = true;
        port dataOut : DataPort;
        port commandIn : DataPort;
        port powerIn : PowerPort;

        action def UpdateDisplay {
            in telemetry : TelemetryData;
            out displayContent : TelemetryData;
        }
        perform UpdateDisplay;

        action def ProcessCommand {
            in command : ControlCommand;
            out processedCommand : ControlCommand;
        }
        perform ProcessCommand;
    }

    part def SafetyTether {
        attribute length : Real = 25.0;
        attribute tensileStrength : ForceValue = 8000.0;
        attribute isAttached : Boolean = true;
        port tetherPort : TetherPort;
    }

    part def SAFERThruster {
        attribute thrustForce : ForceValue = 3.6;
        attribute nitrogenMass : MassValue = 0.5;
        port thrustOut : ThrustPort;
    }

    part def SAFER {
        attribute totalMass : MassValue = 37.0;
        attribute availableDeltaV : VelocityValue = 3.05;
        attribute isArmed : Boolean = false;
        port thrustPort : ThrustPort;

        part thrusters[4] : SAFERThruster {
            port redefines thrustOut;
        }

        action def ActivateThrusters {
            in direction : Dimensionless;
            out thrust : ForceValue;
        }
        perform ActivateThrusters {
            out thrust = 3.6;
        }

        satisfy SAFERRequirement by safer;
    }

    // ===== Top-Level EMU =====
    part def ExtravehicularMobilityUnit {
        attribute systemStatus : SystemStatus = SystemStatus::nominal;
        attribute operationalState : SuitOperationalState = SuitOperationalState::standby;
        attribute currentEVAPhase : EVAPhase = EVAPhase::prebreathing;
        attribute totalMass : MassValue = 127.0;

        port environmentPort : EnvironmentPort;
        port tetherPort : TetherPort;
        port radioLink : VoicePort;
        port dataLink : DataPort;

        part plss : PrimaryLifeSupportSubsystem;
        part pga : PressureGarmentAssembly;
        part helmet : HelmetVisorAssembly;
        part gloves : ExtravehicularGloves;
        part cca : CommunicationCarrierAssembly;
        part dcm : DisplayAndControlModule;
        part tether : SafetyTether;
        part safer : SAFER;

        // Connect PLSS to PGA
        connection plss.oxygenSupply to pga.oxygenIn;
        connection pga.oxygenOut to plss.co2Extraction;
        connection plss.coolantSupply to pga.coolantIn;
        connection pga.coolantOut to plss.coolantReturn;

        // Connect PGA to Helmet
        connection pga.oxygenOut to helmet.oxygenIn;
        connection helmet.oxygenOut to pga.oxygenIn;

        // Connect PLSS power to subsystems
        connection plss.powerSupply to gloves.powerIn;
        connection plss.powerSupply to dcm.powerIn;

        // Connect Communication
        connection cca.radioLink to radioLink;

        // Connect Data
        connection dcm.dataOut to dataLink;
        connection dataLink to dcm.commandIn;

        // Connect Environment
        connection environmentPort to pga.environmentPort;
        connection environmentPort to helmet.environmentPort;

        // Connect Tether
        connection tether.tetherPort to tetherPort;

        // Connect SAFER
        connection safer.thrustPort to tetherPort;

        // ===== State Machine: EVA Mission Phases =====
        state def EVAMissionStateMachine {
            entry; then state prebreathing;
            transition prebreathing_to_depressurization
                first prebreathing
                then depressurization
                when plss.oxygenTank.currentPressure >= 100.0e3;
            state depressurization;
            transition depressurization_to_egress
                first depressurization
                then egress
                when pga.internalPressure <= 4.0e3;
            state egress;
            transition egress_to_operations
                first egress
                then operations
                when tether.isAttached == true;
            state operations;
            transition operations_to_ingress
                first operations
                then ingress
                when currentEVAPhase == EVAPhase::ingress;
            state ingress;
            transition ingress_to_repressurization
                first ingress
                then repressurization
                when tether.isAttached == false;
            state repressurization;
            transition repressurization_to_complete
                first repressurization
                then done
                when pga.internalPressure >= 70.0e3;
            state done;
        }

        // ===== State Machine: System Operational State =====
        state def SystemOperationalStateMachine {
            entry; then state standby;
            transition standby_to_preparation
                first standby
                then preparation
                when operationalState == SuitOperationalState::preparation;
            state preparation;
            transition preparation_to_active
                first preparation
                then active
                when plss.battery.voltage >= 16.0
                and plss.oxygenTank.currentPressure >= 20.7e3;
            state active {
                entry; then state monitoring;
                state monitoring;
                transition monitoring_to_emergency
                    first monitoring
                    then emergency
                    when systemStatus == SystemStatus::critical;
                transition emergency_to_monitoring
                    first emergency
                    then monitoring
                    when systemStatus == SystemStatus::nominal;
            }
            transition active_to_shutdown
                first active
                then shutdown
                when currentEVAPhase == EVAPhase::repressurization;
            state shutdown;
        }

        // ===== Action: Monitor Suit Health =====
        action def MonitorSuitHealth {
            in oxygenData : Oxygen;
            in co2Data : CarbonDioxide;
            in powerData : ElectricalPower;
            in coolantData : CoolantFluid;
            out status : SystemStatus;
            out telemetry : TelemetryData;
        }

        perform MonitorSuitHealth {
            out telemetry = TelemetryData {
                oxygenLevel = 0.95,
                batteryLevel = 0.80,
                suitPressure = 29.6e3,
                coolantTemp = 291.0
            };
            out status = SystemStatus::nominal;
        }

        // ===== Action: Emergency Response =====
        action def EmergencyResponse {
            in status : SystemStatus;
            out armSAFER : Boolean;
            out alertGroundControl : VoiceSignal;
        }

        perform EmergencyResponse {
            out armSAFER = true;
            out alertGroundControl = VoiceSignal { frequency = 415.0e6, amplitude = 1.0; };
        }

        satisfy LifeSupportRequirement;
        satisfy PressureGarmentRequirement;
        satisfy SAFERRequirement;
        satisfy CommunicationRequirement;
    }

    // ===== EVA System (Context) =====
    part def EVASystem {
        attribute missionName : String = "EVA Mission";
        attribute missionDuration : DurationValue = 25200.0;

        part emu : ExtravehicularMobilityUnit;
        part spacecraftInterface {
            port tetherReceptacle : TetherPort;
            port radioGroundLink : VoicePort;
            port dataGroundLink : DataPort;
        }
        part astronaut {
            attribute heartRate : Real = 72.0;
            attribute bodyTemperature : TemperatureValue = 310.0;
        }

        connection emu.tetherPort to spacecraftInterface.tetherReceptacle;
        connection emu.radioLink to spacecraftInterface.radioGroundLink;
        connection emu.dataLink to spacecraftInterface.dataGroundLink;
    }
}
