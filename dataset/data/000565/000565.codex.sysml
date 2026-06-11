package CardiopulmonaryBypassSystemModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Pressure {
        :> ScalarValues::Real;
        unit = "mmHg";
    }

    attribute def FlowRate {
        :> ScalarValues::Real;
        unit = "L/min";
    }

    attribute def Volume {
        :> ScalarValues::Real;
        unit = "mL";
    }

    attribute def Temperature {
        :> ScalarValues::Real;
        unit = "degC";
    }

    attribute def OxygenSaturation {
        :> ScalarValues::Real;
        unit = "%";
    }

    attribute def GasFlowRate {
        :> ScalarValues::Real;
        unit = "L/min";
    }

    attribute def Concentration {
        :> ScalarValues::Real;
        unit = "mmol/L";
    }

    attribute def RotationalSpeed {
        :> ScalarValues::Real;
        unit = "rpm";
    }

    item def VenousBlood {
        attribute oxygenSaturation : OxygenSaturation;
        attribute carbonDioxidePartialPressure : Pressure;
        attribute temperature : Temperature;
        attribute anticoagulated : Boolean;
    }

    item def ArterialBlood {
        attribute oxygenSaturation : OxygenSaturation;
        attribute carbonDioxidePartialPressure : Pressure;
        attribute temperature : Temperature;
        attribute pressure : Pressure;
    }

    item def SweepGas {
        attribute oxygenFraction : ScalarValues::Real;
        attribute flowRate : GasFlowRate;
    }

    item def CardioplegiaSolution {
        attribute potassiumConcentration : Concentration;
        attribute temperature : Temperature;
        attribute volume : Volume;
    }

    port def BloodInletPort {
        in item blood : VenousBlood;
    }

    port def BloodOutletPort {
        out item blood : ArterialBlood;
    }

    port def VenousDrainagePort {
        out item blood : VenousBlood;
    }

    port def ArterialReturnPort {
        in item blood : ArterialBlood;
    }

    port def GasInletPort {
        in item gas : SweepGas;
    }

    port def GasExhaustPort {
        out item gas : SweepGas;
    }

    port def FluidPort {
        inout item blood : VenousBlood;
        inout item oxygenatedBlood : ArterialBlood;
    }

    port def ControlPort {
        in attribute commandedPumpSpeed : RotationalSpeed;
        in attribute commandedGasFlow : GasFlowRate;
        in attribute commandedTemperature : Temperature;
        out attribute measuredFlow : FlowRate;
        out attribute measuredArterialPressure : Pressure;
        out attribute measuredVenousReservoirVolume : Volume;
        out attribute measuredOxygenSaturation : OxygenSaturation;
        out attribute alarmActive : Boolean;
    }

    port def PowerPort {
        in attribute voltage : ScalarValues::Real;
        in attribute available : Boolean;
    }

    part def Patient {
        port venousLine : VenousDrainagePort;
        port arterialLine : ArterialReturnPort;

        attribute nativeCardiacOutput : FlowRate;
        attribute meanArterialPressure : Pressure;
        attribute coreTemperature : Temperature;
        attribute venousOxygenSaturation : OxygenSaturation;
    }

    part def VenousCannula {
        port patientSide : BloodInletPort;
        port circuitSide : BloodOutletPort;

        attribute internalDiameter : Length;
        attribute drainagePressure : Pressure;
    }

    part def ArterialCannula {
        port circuitSide : BloodInletPort;
        port patientSide : BloodOutletPort;

        attribute returnPressure : Pressure;
        attribute internalDiameter : Length;
    }

    part def VenousReservoir {
        port inlet : BloodInletPort;
        port outlet : BloodOutletPort;

        attribute minimumSafeVolume : Volume = 200;
        attribute nominalVolume : Volume = 800;
        attribute maximumVolume : Volume = 2500;
        attribute currentVolume : Volume;
        attribute airDetected : Boolean;
    }

    part def CentrifugalPump {
        port inlet : BloodInletPort;
        port outlet : BloodOutletPort;
        port power : PowerPort;
        port control : ControlPort;

        attribute speed : RotationalSpeed;
        attribute generatedFlow : FlowRate;
        attribute inletPressure : Pressure;
        attribute outletPressure : Pressure;

        action def GenerateBloodFlow {
            in item incomingBlood : VenousBlood;
            in attribute requestedSpeed : RotationalSpeed;
            out item pressurizedBlood : ArterialBlood;
            out attribute deliveredFlow : FlowRate;
        }
    }

    part def MembraneOxygenator {
        port bloodIn : BloodInletPort;
        port bloodOut : BloodOutletPort;
        port gasIn : GasInletPort;
        port gasOut : GasExhaustPort;

        attribute membraneSurfaceArea : Area;
        attribute sweepGasFlow : GasFlowRate;
        attribute outletOxygenSaturation : OxygenSaturation;
        attribute outletCarbonDioxidePartialPressure : Pressure;

        action def ExchangeRespiratoryGases {
            in item lowOxygenBlood : VenousBlood;
            in item oxygenRichGas : SweepGas;
            out item oxygenatedBlood : ArterialBlood;
            out item exhaustGas : SweepGas;
        }
    }

    part def HeatExchanger {
        port bloodIn : BloodInletPort;
        port bloodOut : BloodOutletPort;
        port control : ControlPort;

        attribute targetTemperature : Temperature = 37;
        attribute outletTemperature : Temperature;
        attribute waterBathTemperature : Temperature;

        action def RegulateBloodTemperature {
            in item incomingBlood : VenousBlood;
            in attribute requestedTemperature : Temperature;
            out item conditionedBlood : ArterialBlood;
        }
    }

    part def ArterialFilter {
        port inlet : BloodInletPort;
        port outlet : BloodOutletPort;

        attribute bubbleTrapVolume : Volume = 40;
        attribute particulateRetentionMicron : ScalarValues::Real = 40;
        attribute airDetected : Boolean;
        attribute pressureDrop : Pressure;
    }

    part def CardioplegiaDeliveryModule {
        port arterialSupply : BloodInletPort;
        port cardioplegiaOut : BloodOutletPort;
        port control : ControlPort;

        attribute solutionVolume : Volume;
        attribute deliveryPressure : Pressure;
        attribute solutionTemperature : Temperature;
        attribute active : Boolean;

        item solution : CardioplegiaSolution;

        action def DeliverCardioplegia {
            in item oxygenatedBlood : ArterialBlood;
            in item cardioplegiaSolution : CardioplegiaSolution;
            out item myocardialProtectionFluid : ArterialBlood;
        }
    }

    part def SensorModule {
        port circuitInterface : FluidPort;
        port control : ControlPort;

        attribute measuredFlow : FlowRate;
        attribute measuredArterialPressure : Pressure;
        attribute measuredVenousPressure : Pressure;
        attribute measuredReservoirVolume : Volume;
        attribute measuredOxygenSaturation : OxygenSaturation;
        attribute measuredTemperature : Temperature;
        attribute airInLineDetected : Boolean;
    }

    part def ControlConsole {
        port pumpControl : ControlPort;
        port oxygenatorControl : ControlPort;
        port temperatureControl : ControlPort;
        port sensorInput : ControlPort;
        port power : PowerPort;

        attribute targetFlow : FlowRate = 4.8;
        attribute targetMeanArterialPressure : Pressure = 65;
        attribute targetOxygenSaturation : OxygenSaturation = 95;
        attribute targetTemperature : Temperature = 37;
        attribute alarmActive : Boolean;

        action def ComputeSupportCommands {
            in attribute measuredFlow : FlowRate;
            in attribute measuredPressure : Pressure;
            in attribute measuredSaturation : OxygenSaturation;
            in attribute measuredReservoirVolume : Volume;
            out attribute pumpSpeedCommand : RotationalSpeed;
            out attribute gasFlowCommand : GasFlowRate;
            out attribute temperatureCommand : Temperature;
            out attribute alarmCommand : Boolean;
        }
    }

    part def BackupPowerSupply {
        port output : PowerPort;

        attribute remainingRuntime : Time;
        attribute voltage : ScalarValues::Real = 24;
        attribute available : Boolean;
    }

    part def CardiopulmonaryBypassMachine {
        port venousPatientConnection : BloodInletPort;
        port arterialPatientConnection : BloodOutletPort;
        port sweepGasSupply : GasInletPort;
        port sweepGasExhaust : GasExhaustPort;
        port electricalSupply : PowerPort;

        part reservoir : VenousReservoir;
        part pump : CentrifugalPump;
        part oxygenator : MembraneOxygenator;
        part heaterCooler : HeatExchanger;
        part arterialFilter : ArterialFilter;
        part cardioplegia : CardioplegiaDeliveryModule;
        part sensors : SensorModule;
        part console : ControlConsole;
        part backupPower : BackupPowerSupply;

        attribute supportedBloodFlow : FlowRate;
        attribute arterialLinePressure : Pressure;
        attribute venousReservoirVolume : Volume;
        attribute patientReturnTemperature : Temperature;
        attribute patientReturnOxygenSaturation : OxygenSaturation;

        connection venousDrainagePath
            connect venousPatientConnection to reservoir.inlet;

        connection reservoirToPump
            connect reservoir.outlet to pump.inlet;

        connection pumpToOxygenator
            connect pump.outlet to oxygenator.bloodIn;

        connection oxygenatorToHeatExchanger
            connect oxygenator.bloodOut to heaterCooler.bloodIn;

        connection heatExchangerToFilter
            connect heaterCooler.bloodOut to arterialFilter.inlet;

        connection filterToPatient
            connect arterialFilter.outlet to arterialPatientConnection;

        connection gasSupplyPath
            connect sweepGasSupply to oxygenator.gasIn;

        connection gasExhaustPath
            connect oxygenator.gasOut to sweepGasExhaust;

        connection cardioplegiaSupplyPath
            connect arterialFilter.outlet to cardioplegia.arterialSupply;

        connection pumpCommandPath
            connect console.pumpControl to pump.control;

        connection oxygenatorCommandPath
            connect console.oxygenatorControl to oxygenator.gasIn;

        connection temperatureCommandPath
            connect console.temperatureControl to heaterCooler.control;

        connection sensorFeedbackPath
            connect sensors.control to console.sensorInput;

        connection mainPowerPath
            connect electricalSupply to console.power;

        connection backupPowerPath
            connect backupPower.output to pump.power;
    }

    part def OperatingRoomBypassConfiguration {
        part patient : Patient;
        part bypassMachine : CardiopulmonaryBypassMachine;

        connection patientVenousToMachine
            connect patient.venousLine to bypassMachine.venousPatientConnection;

        connection machineArterialToPatient
            connect bypassMachine.arterialPatientConnection to patient.arterialLine;
    }

    action def ProvideExtracorporealCirculation {
        in item systemicVenousBlood : VenousBlood;
        in item oxygenSupplyGas : SweepGas;
        out item systemicArterialBlood : ArterialBlood;

        first startBypass;
        then drainVenousBlood;
        then pumpBlood;
        then oxygenateBlood;
        then regulateTemperature;
        then filterAirAndParticulates;
        then returnArterialBlood;

        action startBypass;
        action drainVenousBlood {
            in item blood : VenousBlood = systemicVenousBlood;
            out item drainedBlood : VenousBlood;
        }
        action pumpBlood {
            in item drainedBlood : VenousBlood;
            out item pressurizedBlood : ArterialBlood;
        }
        action oxygenateBlood {
            in item pressurizedBlood : ArterialBlood;
            in item gas : SweepGas = oxygenSupplyGas;
            out item oxygenatedBlood : ArterialBlood;
        }
        action regulateTemperature {
            in item oxygenatedBlood : ArterialBlood;
            out item temperatureControlledBlood : ArterialBlood;
        }
        action filterAirAndParticulates {
            in item temperatureControlledBlood : ArterialBlood;
            out item filteredBlood : ArterialBlood;
        }
        action returnArterialBlood {
            in item filteredBlood : ArterialBlood;
            out item bloodReturnedToPatient : ArterialBlood = systemicArterialBlood;
        }
    }

    state def BypassOperationalState {
        entry action InitializeMonitoring;

        state Standby;
        state Priming;
        state Ready;
        state InitiatingBypass;
        state FullBypassSupport;
        state PartialBypassSupport;
        state Weaning;
        state AlarmHold;
        state Terminated;

        transition first Standby;

        transition Standby_to_Priming
            first Standby
            then Priming
            accept StartPriming;

        transition Priming_to_Ready
            first Priming
            then Ready
            if reservoir.currentVolume >= reservoir.minimumSafeVolume and not reservoir.airDetected;

        transition Ready_to_Initiating
            first Ready
            then InitiatingBypass
            accept BeginBypass;

        transition Initiating_to_FullSupport
            first InitiatingBypass
            then FullBypassSupport
            if pump.generatedFlow >= 2.4 and oxygenator.outletOxygenSaturation >= 90;

        transition Full_to_Partial
            first FullBypassSupport
            then PartialBypassSupport
            accept ReduceSupport;

        transition Partial_to_Weaning
            first PartialBypassSupport
            then Weaning
            if patient.nativeCardiacOutput >= 3.5;

        transition Weaning_to_Terminated
            first Weaning
            then Terminated
            if pump.generatedFlow <= 0.5 and patient.meanArterialPressure >= 60;

        transition Any_to_AlarmHold
            first FullBypassSupport
            then AlarmHold
            if reservoir.airDetected or arterialFilter.airDetected or reservoir.currentVolume < reservoir.minimumSafeVolume;

        transition AlarmHold_to_Ready
            first AlarmHold
            then Ready
            accept AlarmCleared;
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The cardiopulmonary bypass system shall temporarily assume the primary pumping and gas exchange functions of the heart and lungs by draining venous blood from the patient, oxygenating it, removing carbon dioxide, controlling its temperature, filtering air and particulates, and returning pressurized arterial blood to systemic circulation during cardiac surgery. */
    }

    requirement def FlowSupportRequirement {
        subject bypassMachine : CardiopulmonaryBypassMachine;
        attribute minimumAdultFlow : FlowRate = 2.4;
        attribute nominalAdultFlow : FlowRate = 4.8;

        require constraint {
            bypassMachine.supportedBloodFlow >= minimumAdultFlow and
            bypassMachine.supportedBloodFlow <= 6.5
        }
    }

    requirement def OxygenationRequirement {
        subject bypassMachine : CardiopulmonaryBypassMachine;
        attribute minimumReturnSaturation : OxygenSaturation = 95;

        require constraint {
            bypassMachine.patientReturnOxygenSaturation >= minimumReturnSaturation
        }
    }

    requirement def PressureSafetyRequirement {
        subject bypassMachine : CardiopulmonaryBypassMachine;
        attribute maximumArterialLinePressure : Pressure = 300;

        require constraint {
            bypassMachine.arterialLinePressure <= maximumArterialLinePressure
        }
    }

    requirement def ReservoirSafetyRequirement {
        subject bypassMachine : CardiopulmonaryBypassMachine;
        attribute minimumReservoirVolume : Volume = 200;

        require constraint {
            bypassMachine.venousReservoirVolume >= minimumReservoirVolume
        }
    }

    requirement def ThermalManagementRequirement {
        subject bypassMachine : CardiopulmonaryBypassMachine;
        attribute minimumBloodTemperature : Temperature = 18;
        attribute maximumBloodTemperature : Temperature = 37;

        require constraint {
            bypassMachine.patientReturnTemperature >= minimumBloodTemperature and
            bypassMachine.patientReturnTemperature <= maximumBloodTemperature
        }
    }

    requirement def AirEmbolismProtectionRequirement {
        subject bypassMachine : CardiopulmonaryBypassMachine;

        require constraint {
            not bypassMachine.reservoir.airDetected and
            not bypassMachine.arterialFilter.airDetected
        }
    }

    satisfy PrimaryFunctionRequirement by CardiopulmonaryBypassMachine;
    satisfy FlowSupportRequirement by CentrifugalPump;
    satisfy OxygenationRequirement by MembraneOxygenator;
    satisfy PressureSafetyRequirement by ControlConsole;
    satisfy ReservoirSafetyRequirement by VenousReservoir;
    satisfy ThermalManagementRequirement by HeatExchanger;
    satisfy AirEmbolismProtectionRequirement by ArterialFilter;

    part bypassScenario : OperatingRoomBypassConfiguration {
        part patient {
            attribute nativeCardiacOutput = 0.5;
            attribute meanArterialPressure = 65;
            attribute coreTemperature = 36.5;
            attribute venousOxygenSaturation = 70;
        }

        part bypassMachine {
            attribute supportedBloodFlow = 4.8;
            attribute arterialLinePressure = 180;
            attribute venousReservoirVolume = 900;
            attribute patientReturnTemperature = 36.8;
            attribute patientReturnOxygenSaturation = 98;
        }
    }
}