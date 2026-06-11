package OxygenConcentratorSystemModel {

    attribute def Percentage {
        :> ISQ::quantityValue;
        unit = "%";
    }

    attribute def LiterPerMinute {
        :> ISQ::quantityValue;
        unit = "L/min";
    }

    attribute def Kilopascal {
        :> ISQ::quantityValue;
        unit = "kPa";
    }

    attribute def Watt {
        :> ISQ::quantityValue;
        unit = "W";
    }

    attribute def DegreeCelsius {
        :> ISQ::quantityValue;
        unit = "degC";
    }

    attribute def DecibelA {
        :> ISQ::quantityValue;
        unit = "dBA";
    }

    attribute def Hour {
        :> ISQ::quantityValue;
        unit = "h";
    }

    item def AmbientAir {
        attribute oxygenFraction : Percentage;
        attribute nitrogenFraction : Percentage;
        attribute particulateLoad;
        attribute humidity;
    }

    item def ConcentratedOxygen {
        attribute oxygenPurity : Percentage;
        attribute flowRate : LiterPerMinute;
        attribute outletPressure : Kilopascal;
        attribute temperature : DegreeCelsius;
    }

    item def ExhaustGas {
        attribute nitrogenFraction : Percentage;
        attribute oxygenFraction : Percentage;
        attribute exhaustFlowRate : LiterPerMinute;
    }

    item def ElectricalPower {
        attribute voltage;
        attribute frequency;
        attribute consumedPower : Watt;
    }

    item def ControlSignal {
        attribute commandCode;
        attribute setPoint;
    }

    item def AlarmSignal {
        attribute alarmCode;
        attribute severity;
        attribute active;
    }

    item def UserSetting {
        attribute prescribedFlowRate : LiterPerMinute;
        attribute operationMode;
    }

    port def AirInletPort {
        in item air : AmbientAir;
    }

    port def OxygenOutletPort {
        out item oxygen : ConcentratedOxygen;
    }

    port def ExhaustOutletPort {
        out item exhaust : ExhaustGas;
    }

    port def PowerInputPort {
        in item power : ElectricalPower;
    }

    port def ControlPort {
        in item setting : UserSetting;
        out item alarm : AlarmSignal;
    }

    part def IntakeFilter {
        port inlet : AirInletPort;
        port filteredAirOut : AirInletPort;
        attribute filterEfficiency : Percentage;
        attribute replacementInterval : Hour;
    }

    part def Compressor {
        port airIn : AirInletPort;
        port compressedAirOut : AirInletPort;
        port powerIn : PowerInputPort;
        attribute dischargePressure : Kilopascal;
        attribute nominalPower : Watt;
        attribute operatingTemperature : DegreeCelsius;
    }

    part def CoolingSystem {
        port hotAirIn : AirInletPort;
        port cooledAirOut : AirInletPort;
        port powerIn : PowerInputPort;
        attribute outletTemperature : DegreeCelsius;
        attribute fanPower : Watt;
    }

    part def MolecularSieveBed {
        port compressedAirIn : AirInletPort;
        port oxygenRichGasOut : OxygenOutletPort;
        port nitrogenExhaustOut : ExhaustOutletPort;
        attribute zeoliteMass;
        attribute adsorptionPressure : Kilopascal;
        attribute regenerationPressure : Kilopascal;
        attribute cycleTime;
    }

    part def ProductTank {
        port oxygenIn : OxygenOutletPort;
        port oxygenOut : OxygenOutletPort;
        attribute storedPressure : Kilopascal;
        attribute tankVolume;
    }

    part def FlowRegulator {
        port oxygenIn : OxygenOutletPort;
        port oxygenOut : OxygenOutletPort;
        port controlIn : ControlPort;
        attribute commandedFlow : LiterPerMinute;
        attribute deliveredFlow : LiterPerMinute;
    }

    part def OxygenPuritySensor {
        port sampledOxygenIn : OxygenOutletPort;
        attribute measuredPurity : Percentage;
        attribute measurementAccuracy : Percentage;
    }

    part def PressureSensor {
        port sampledOxygenIn : OxygenOutletPort;
        attribute measuredPressure : Kilopascal;
        attribute pressureLimitHigh : Kilopascal;
        attribute pressureLimitLow : Kilopascal;
    }

    part def Controller {
        port userInterface : ControlPort;
        port powerIn : PowerInputPort;
        attribute targetFlowRate : LiterPerMinute;
        attribute minimumAcceptablePurity : Percentage;
        attribute alarmActive;
        attribute serviceHours : Hour;
    }

    part def UserInterface {
        port userControls : ControlPort;
        attribute displayedFlowRate : LiterPerMinute;
        attribute displayedPurity : Percentage;
        attribute alarmIndicatorActive;
    }

    part def OxygenConcentrator {
        port ambientAirIn : AirInletPort;
        port oxygenDeliveryOut : OxygenOutletPort;
        port nitrogenExhaustOut : ExhaustOutletPort;
        port mainsPowerIn : PowerInputPort;
        port operatorInterface : ControlPort;

        attribute ratedOxygenPurity : Percentage = 93 [%];
        attribute ratedFlowRate : LiterPerMinute = 5 [L/min];
        attribute maximumPowerConsumption : Watt = 350 [W];
        attribute maximumSoundLevel : DecibelA = 45 [dBA];
        attribute minimumServiceLife : Hour = 20000 [h];

        part filter : IntakeFilter {
            attribute filterEfficiency = 95 [%];
            attribute replacementInterval = 1000 [h];
        }

        part compressor : Compressor {
            attribute dischargePressure = 220 [kPa];
            attribute nominalPower = 260 [W];
            attribute operatingTemperature = 65 [degC];
        }

        part cooler : CoolingSystem {
            attribute outletTemperature = 38 [degC];
            attribute fanPower = 25 [W];
        }

        part sieveAssembly : MolecularSieveBed {
            attribute adsorptionPressure = 210 [kPa];
            attribute regenerationPressure = 105 [kPa];
        }

        part productTank : ProductTank {
            attribute storedPressure = 160 [kPa];
        }

        part regulator : FlowRegulator {
            attribute commandedFlow = 2 [L/min];
            attribute deliveredFlow = 2 [L/min];
        }

        part puritySensor : OxygenPuritySensor {
            attribute measuredPurity = 93 [%];
            attribute measurementAccuracy = 2 [%];
        }

        part pressureSensor : PressureSensor {
            attribute measuredPressure = 140 [kPa];
            attribute pressureLimitHigh = 180 [kPa];
            attribute pressureLimitLow = 90 [kPa];
        }

        part controller : Controller {
            attribute targetFlowRate = 2 [L/min];
            attribute minimumAcceptablePurity = 87 [%];
            attribute alarmActive = false;
            attribute serviceHours = 0 [h];
        }

        part ui : UserInterface {
            attribute displayedFlowRate = 2 [L/min];
            attribute displayedPurity = 93 [%];
            attribute alarmIndicatorActive = false;
        }

        connect ambientAirIn to filter.inlet;
        connect filter.filteredAirOut to compressor.airIn;
        connect mainsPowerIn to compressor.powerIn;
        connect compressor.compressedAirOut to cooler.hotAirIn;
        connect mainsPowerIn to cooler.powerIn;
        connect cooler.cooledAirOut to sieveAssembly.compressedAirIn;
        connect sieveAssembly.oxygenRichGasOut to productTank.oxygenIn;
        connect sieveAssembly.nitrogenExhaustOut to nitrogenExhaustOut;
        connect productTank.oxygenOut to regulator.oxygenIn;
        connect regulator.oxygenOut to oxygenDeliveryOut;
        connect regulator.oxygenOut to puritySensor.sampledOxygenIn;
        connect productTank.oxygenOut to pressureSensor.sampledOxygenIn;
        connect operatorInterface to ui.userControls;
        connect ui.userControls to controller.userInterface;
        connect controller.userInterface to regulator.controlIn;
        connect mainsPowerIn to controller.powerIn;
    }

    action def ConcentrateOxygen {
        in item incomingAir : AmbientAir;
        in item power : ElectricalPower;
        in item setting : UserSetting;
        out item deliveredOxygen : ConcentratedOxygen;
        out item exhaustGas : ExhaustGas;
        out item alarm : AlarmSignal;

        first startCompression;
        then removeParticulates;
        then coolCompressedAir;
        then adsorbNitrogen;
        then storeOxygen;
        then regulateFlow;
        then monitorPurityAndPressure;
        then deliverOxygen;

        action startCompression;
        action removeParticulates;
        action coolCompressedAir;
        action adsorbNitrogen;
        action storeOxygen;
        action regulateFlow;
        action monitorPurityAndPressure;
        action deliverOxygen;
    }

    state def OxygenConcentratorOperatingState {
        state Off;
        state Startup;
        state Concentrating;
        state DeliveringOxygen;
        state Alarm;
        state Shutdown;

        initial then Off;

        transition Off_to_Startup
            first Off
            accept item power : ElectricalPower
            then Startup;

        transition Startup_to_Concentrating
            first Startup
            if power.consumedPower <= 350 [W]
            then Concentrating;

        transition Concentrating_to_Delivering
            first Concentrating
            if true
            then DeliveringOxygen;

        transition Delivering_to_AlarmLowPurity
            first DeliveringOxygen
            if true
            then Alarm;

        transition Alarm_to_Shutdown
            first Alarm
            accept item setting : UserSetting
            then Shutdown;

        transition Shutdown_to_Off
            first Shutdown
            then Off;
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The oxygen concentrator shall take ambient air, remove nitrogen by pressure swing adsorption, and provide a continuous controlled flow of oxygen-enriched gas to a patient outlet. */
        subject concentrator : OxygenConcentrator;
        require constraint {
            concentrator.ratedOxygenPurity >= 90 [%] and
            concentrator.ratedFlowRate >= 1 [L/min]
        }
    }

    requirement def OxygenPurityRequirement {
        doc /* During normal delivery, oxygen purity at the outlet shall remain at or above 87 percent for the configured flow range. */
        subject oxygen : ConcentratedOxygen;
        require constraint {
            oxygen.oxygenPurity >= 87 [%]
        }
    }

    requirement def FlowControlRequirement {
        doc /* The system shall regulate delivered oxygen flow according to the user-selected prescribed flow setting. */
        subject regulator : FlowRegulator;
        require constraint {
            regulator.deliveredFlow >= 0.5 [L/min] and
            regulator.deliveredFlow <= 5 [L/min]
        }
    }

    requirement def PressureSafetyRequirement {
        doc /* Product tank pressure shall remain within the safe operating pressure range. */
        subject pressureSensor : PressureSensor;
        require constraint {
            pressureSensor.measuredPressure >= pressureSensor.pressureLimitLow and
            pressureSensor.measuredPressure <= pressureSensor.pressureLimitHigh
        }
    }

    requirement def PowerConsumptionRequirement {
        doc /* The concentrator shall operate from mains electrical power without exceeding rated maximum power consumption. */
        subject concentrator : OxygenConcentrator;
        require constraint {
            concentrator.maximumPowerConsumption <= 350 [W]
        }
    }

    requirement def AlarmRequirement {
        doc /* The controller shall generate an alarm when oxygen purity is below the minimum acceptable threshold or pressure is outside limits. */
        subject controller : Controller;
        require constraint {
            controller.minimumAcceptablePurity == 87 [%]
        }
    }

    requirement def NoiseRequirement {
        doc /* The concentrator shall support home medical use by limiting acoustic noise during normal operation. */
        subject concentrator : OxygenConcentrator;
        require constraint {
            concentrator.maximumSoundLevel <= 45 [dBA]
        }
    }

    satisfy PrimaryFunctionRequirement by OxygenConcentrator;
    satisfy FlowControlRequirement by FlowRegulator;
    satisfy PowerConsumptionRequirement by OxygenConcentrator;
    satisfy NoiseRequirement by OxygenConcentrator;
    satisfy AlarmRequirement by Controller;
    satisfy PressureSafetyRequirement by PressureSensor;
}