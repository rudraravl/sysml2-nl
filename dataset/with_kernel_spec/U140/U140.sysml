package IndoorAirIonizerSystem {
    public import ScalarValues::*;
    public import ISQ::*;

    attribute def Voltage :> Real;
    attribute def Current :> Real;
    attribute def Power :> Real;
    attribute def AirFlowRate :> Real;
    attribute def ParticleConcentration :> Real;
    attribute def IonConcentration :> Real;
    attribute def OzoneConcentration :> Real;
    attribute def FanSpeed :> Real;
    attribute def IonizationIntensity :> Real;
    attribute def Percentage :> Real;

    enum def OperatingMode {
        enum off;
        enum standby;
        enum low;
        enum medium;
        enum high;
        enum auto;
    }

    item def RoomAir {
        attribute particulateLevel : ParticleConcentration;
        attribute pollenLevel : ParticleConcentration;
        attribute dustLevel : ParticleConcentration;
        attribute negativeIonLevel : IonConcentration;
        attribute ozoneLevel : OzoneConcentration;
        attribute flowRate : AirFlowRate;
    }

    item def FilteredAir :> RoomAir {
        attribute largeParticulateRemoved : Boolean;
    }

    item def IonizedAir :> FilteredAir {
        attribute chargedParticleLevel : ParticleConcentration;
    }

    item def PurifiedAir :> IonizedAir {
        attribute ozoneNeutralized : Boolean;
    }

    item def ElectricalPower {
        attribute voltage : Voltage;
        attribute current : Current;
        attribute power : Power;
    }

    item def SensorReading {
        attribute measuredParticulateLevel : ParticleConcentration;
        attribute measuredIonLevel : IonConcentration;
        attribute measuredOzoneLevel : OzoneConcentration;
        attribute airQualityIndex : Integer;
    }

    item def FanControlCommand {
        attribute targetSpeed : FanSpeed;
        attribute enabled : Boolean;
    }

    item def IonizationControlCommand {
        attribute targetVoltage : Voltage;
        attribute targetIntensity : IonizationIntensity;
        attribute activeNeedleCount : Integer;
        attribute enabled : Boolean;
    }

    item def UserModeSelection {
        attribute selectedMode : OperatingMode;
        attribute timestamp : Real;
    }

    port def AirInputPort {
        in airIn : RoomAir;
    }

    port def AirOutputPort {
        out airOut : PurifiedAir;
    }

    port def PowerInputPort {
        in powerIn : ElectricalPower;
    }

    port def PowerOutputPort {
        out powerOut : ElectricalPower;
    }

    port def SensorOutputPort {
        out sensorData : SensorReading;
    }

    port def FanCommandPort {
        in fanCommand : FanControlCommand;
    }

    port def IonizationCommandPort {
        in ionizationCommand : IonizationControlCommand;
    }

    port def ModeSelectionPort {
        out modeSelection : UserModeSelection;
    }

    part def CirculationFan {
        port airInlet : AirInputPort;
        port airOutlet {
            out movedAir : RoomAir;
        }
        port powerPort : PowerInputPort;
        port commandPort : FanCommandPort;

        attribute currentSpeed : FanSpeed;
        attribute maxSpeed : FanSpeed;
        attribute airFlowCapacity : AirFlowRate;

        action drawAndMoveAir {
            in ambientAir : RoomAir;
            in speedCommand : FanControlCommand;
            out drawnAir : RoomAir;
        }
    }

    part def PreFilter {
        port airInlet {
            in incomingAir : RoomAir;
        }
        port airOutlet {
            out filteredAir : FilteredAir;
        }

        attribute filterType : String;
        attribute hepaCompliant : Boolean;
        attribute largeDustEfficiency : Percentage;
        attribute pollenEfficiency : Percentage;

        action trapLargeParticles {
            in unfilteredAir : RoomAir;
            out prefilteredAir : FilteredAir;
        }
    }

    part def PowerSupply {
        port mainPowerIn : PowerInputPort;
        port lowVoltageOut : PowerOutputPort;

        attribute inputVoltage : Voltage;
        attribute outputVoltage : Voltage;
        attribute ratedPower : Power;
        attribute efficiency : Percentage;

        action convertMainsPower {
            in mainsInput : ElectricalPower;
            out lowVoltageOutput : ElectricalPower;
        }
    }

    part def HighVoltageGenerator {
        port lowVoltageIn : PowerInputPort;
        port highVoltageOut : PowerOutputPort;
        port commandPort : IonizationCommandPort;

        attribute inputVoltage : Voltage;
        attribute outputVoltage : Voltage;
        attribute nominalOutputVoltage : Voltage;
        attribute conversionEfficiency : Percentage;

        action generateHighVoltage {
            in lowVoltagePower : ElectricalPower;
            in controlCommand : IonizationControlCommand;
            out highVoltagePower : ElectricalPower;
        }
    }

    part def IonizationNeedle {
        port highVoltageIn : PowerInputPort;
        port airStream {
            in airIn : FilteredAir;
            out airOut : IonizedAir;
        }

        attribute needleVoltage : Voltage;
        attribute ionEmissionRate : IonConcentration;
        attribute enabled : Boolean;

        action emitNegativeIons {
            in filteredAir : FilteredAir;
            in highVoltagePower : ElectricalPower;
            out ionizedAir : IonizedAir;
        }
    }

    part def IonizationChamber {
        port airInlet {
            in filteredAir : FilteredAir;
        }
        port airOutlet {
            out ionizedAir : IonizedAir;
        }
        port highVoltageIn : PowerInputPort;

        part needles : IonizationNeedle[6];

        attribute chamberVoltage : Voltage;
        attribute totalIonDensity : IonConcentration;
        attribute activeNeedleCount : Integer;

        flow needlePowerFlow1 of ElectricalPower
            from highVoltageIn.powerIn to needles[1].highVoltageIn.powerIn;
        flow needlePowerFlow2 of ElectricalPower
            from highVoltageIn.powerIn to needles[2].highVoltageIn.powerIn;
        flow needlePowerFlow3 of ElectricalPower
            from highVoltageIn.powerIn to needles[3].highVoltageIn.powerIn;
        flow needlePowerFlow4 of ElectricalPower
            from highVoltageIn.powerIn to needles[4].highVoltageIn.powerIn;
        flow needlePowerFlow5 of ElectricalPower
            from highVoltageIn.powerIn to needles[5].highVoltageIn.powerIn;
        flow needlePowerFlow6 of ElectricalPower
            from highVoltageIn.powerIn to needles[6].highVoltageIn.powerIn;

        action chargeParticles {
            in prefilteredAir : FilteredAir;
            in highVoltagePower : ElectricalPower;
            out chargedAir : IonizedAir;
        }
    }

    part def OzoneCatalyst {
        port airInlet {
            in ionizedAir : IonizedAir;
        }
        port airOutlet {
            out purifiedAir : PurifiedAir;
        }

        attribute catalystType : String;
        attribute ozoneReductionEfficiency : Percentage;
        attribute outputOzoneLevel : OzoneConcentration;

        action neutralizeOzone {
            in contaminatedAir : IonizedAir;
            out safeAir : PurifiedAir;
        }
    }

    part def AirQualitySensor {
        port airSample {
            in sampledAir : RoomAir;
        }
        port measurementOut : SensorOutputPort;

        attribute particulateSensitivity : ParticleConcentration;
        attribute ionSensitivity : IonConcentration;
        attribute ozoneSensitivity : OzoneConcentration;
        attribute measurementInterval : Real;

        action measureAirQuality {
            in airSample : RoomAir;
            out sensorReading : SensorReading;
        }
    }

    part def UserInterface {
        port modeSelectionOut : ModeSelectionPort;
        port statusDisplay {
            in systemStatus : OperatingMode;
        }

        attribute displayEnabled : Boolean;
        attribute lastUserInput : Real;
    }

    part def ControlModule {
        port sensorDataIn {
            in sensorReading : SensorReading;
        }
        port userModeIn {
            in modeSelection : UserModeSelection;
        }
        port fanCommandOut {
            out fanCommand : FanControlCommand;
        }
        port ionizationCommandOut {
            out ionizationCommand : IonizationControlCommand;
        }

        attribute currentMode : OperatingMode;
        attribute targetParticulateLevel : ParticleConcentration;
        attribute targetIonLevel : IonConcentration;
        attribute autoModeEnabled : Boolean;
        attribute commandedFanSpeed : FanSpeed;
        attribute commandedIonIntensity : IonizationIntensity;

        action computeControlCommands {
            in selectedMode : UserModeSelection;
            in airQualityData : SensorReading;
            out fanControl : FanControlCommand;
            out ionizationControl : IonizationControlCommand;
        }

        state controlStateMachine {
            entry; then offState;

            state offState;
            
            transition offToStandby
                first offState
                accept modeChange : UserModeSelection
                if modeChange.selectedMode == OperatingMode::standby
                then standbyState;

            state standbyState;
            
            transition standbyToOff
                first standbyState
                accept modeChange : UserModeSelection
                if modeChange.selectedMode == OperatingMode::off
                then offState;
            transition standbyToLow
                first standbyState
                accept modeChange : UserModeSelection
                if modeChange.selectedMode == OperatingMode::low
                then lowState;

            state lowState;
            
            transition lowToMedium
                first lowState
                accept modeChange : UserModeSelection
                if modeChange.selectedMode == OperatingMode::medium
                then mediumState;
            transition lowToStandby
                first lowState
                accept modeChange : UserModeSelection
                if modeChange.selectedMode == OperatingMode::standby
                then standbyState;

            state mediumState;
            
            transition mediumToHigh
                first mediumState
                accept modeChange : UserModeSelection
                if modeChange.selectedMode == OperatingMode::high
                then highState;
            transition mediumToLow
                first mediumState
                accept modeChange : UserModeSelection
                if modeChange.selectedMode == OperatingMode::low
                then lowState;

            state highState;
            
            transition highToMedium
                first highState
                accept modeChange : UserModeSelection
                if modeChange.selectedMode == OperatingMode::medium
                then mediumState;
            transition highToAuto
                first highState
                accept modeChange : UserModeSelection
                if modeChange.selectedMode == OperatingMode::auto
                then autoState;

            state autoState;
            
            transition autoToStandby
                first autoState
                accept modeChange : UserModeSelection
                if modeChange.selectedMode == OperatingMode::standby
                then standbyState;
        }
    }

    part def IndoorAirIonizer {
        port roomAirIn : AirInputPort;
        port purifiedAirOut : AirOutputPort;
        port mainsPowerIn : PowerInputPort;
        port userControl : ModeSelectionPort;

        part powerSupply : PowerSupply;
        part circulationFan : CirculationFan;
        part preFilter : PreFilter {
            attribute :>> filterType = "HEPA";
            attribute :>> hepaCompliant = true;
            attribute :>> largeDustEfficiency = 99.97;
            attribute :>> pollenEfficiency = 99.5;
        }
        part highVoltageGenerator : HighVoltageGenerator {
            attribute :>> nominalOutputVoltage = 7000.0;
        }
        part ionizationChamber : IonizationChamber {
            attribute :>> activeNeedleCount = 6;
        }
        part ozoneCatalyst : OzoneCatalyst {
            attribute :>> ozoneReductionEfficiency = 95.0;
        }
        part airQualitySensor : AirQualitySensor;
        part controlModule : ControlModule;
        part userInterface : UserInterface;

        interface powerSupplyInterface connect mainsPowerIn to powerSupply.mainPowerIn {
            flow mainsPowerFlow of ElectricalPower
                from mainsPowerIn.powerIn to powerSupply.mainPowerIn.powerIn;
        }

        interface lowVoltageInterface connect powerSupply.lowVoltageOut to highVoltageGenerator.lowVoltageIn {
            flow lowVoltagePowerFlow of ElectricalPower
                from powerSupply.lowVoltageOut.powerOut to highVoltageGenerator.lowVoltageIn.powerIn;
        }

        interface highVoltageInterface connect highVoltageGenerator.highVoltageOut to ionizationChamber.highVoltageIn {
            flow highVoltagePowerFlow of ElectricalPower
                from highVoltageGenerator.highVoltageOut.powerOut to ionizationChamber.highVoltageIn.powerIn;
        }

        bind roomAirIn = circulationFan.airInlet;

        flow fanToPreFilterAirFlow of RoomAir
            from circulationFan.airOutlet.movedAir to preFilter.airInlet.incomingAir;

        flow preFilterToChamberAirFlow of FilteredAir
            from preFilter.airOutlet.filteredAir to ionizationChamber.airInlet.filteredAir;

        flow chamberToCatalystAirFlow of IonizedAir
            from ionizationChamber.airOutlet.ionizedAir to ozoneCatalyst.airInlet.ionizedAir;

        flow catalystToRoomAirFlow of PurifiedAir
            from ozoneCatalyst.airOutlet.purifiedAir to purifiedAirOut.airOut;

        flow sensorSamplingFlow of RoomAir
            from roomAirIn.airIn to airQualitySensor.airSample.sampledAir;

        flow sensorDataFlow of SensorReading
            from airQualitySensor.measurementOut.sensorData to controlModule.sensorDataIn.sensorReading;

        flow userModeFlow of UserModeSelection
            from userInterface.modeSelectionOut.modeSelection to controlModule.userModeIn.modeSelection;

        flow fanCommandFlow of FanControlCommand
            from controlModule.fanCommandOut.fanCommand to circulationFan.commandPort.fanCommand;

        flow ionizationCommandFlow of IonizationControlCommand
            from controlModule.ionizationCommandOut.ionizationCommand to highVoltageGenerator.commandPort.ionizationCommand;
    }

    action def PurifyIndoorAir {
        in ambientRoomAir : RoomAir;
        in userMode : UserModeSelection;
        out cleanAir : PurifiedAir;

        action measureAirQuality : AirQualitySensor::measureAirQuality {
            in airSample = PurifyIndoorAir::ambientRoomAir;
        }

        action computeControls : ControlModule::computeControlCommands {
            in selectedMode = PurifyIndoorAir::userMode;
            in airQualityData = measureAirQuality.sensorReading;
        }

        action drawAir : CirculationFan::drawAndMoveAir {
            in ambientAir = PurifyIndoorAir::ambientRoomAir;
            in speedCommand = computeControls.fanControl;
        }

        action filterLargeParticles : PreFilter::trapLargeParticles {
            in unfilteredAir = drawAir.drawnAir;
        }

        action generatePower : HighVoltageGenerator::generateHighVoltage {
            in controlCommand = computeControls.ionizationControl;
        }

        action ionizeAir : IonizationChamber::chargeParticles {
            in prefilteredAir = filterLargeParticles.prefilteredAir;
            in highVoltagePower = generatePower.highVoltagePower;
        }

        action neutralizeByproduct : OzoneCatalyst::neutralizeOzone {
            in contaminatedAir = ionizeAir.chargedAir;
            out safeAir = PurifyIndoorAir::cleanAir;
        }

        first start;
        then measureAirQuality;
        then computeControls;
        then drawAir;
        then filterLargeParticles;
        then generatePower;
        then ionizeAir;
        then neutralizeByproduct;
        then done;
    }
}
