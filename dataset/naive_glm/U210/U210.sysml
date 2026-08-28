package PortableOxygenConcentrator {

    package Units {
        unit kg;
        unit L_per_min;
        unit kPa;
        unit degC;
        unit percent;
        unit V;
        unit A;
        unit W;
        unit s;
        unit dB;
        unit Wh;
    }

    package ValueTypes {
        value type Mass :> Real { unit kg; }
        value type VolumeFlowRate :> Real { unit L_per_min; }
        value type Pressure :> Real { unit kPa; }
        value type Temperature :> Real { unit degC; }
        value type Percentage :> Real { unit percent; }
        value type Voltage :> Real { unit V; }
        value type Current :> Real { unit A; }
        value type Power :> Real { unit W; }
        value type Duration :> Real { unit s; }
        value type SoundLevel :> Real { unit dB; }
        value type Energy :> Real { unit Wh; }
    }

    package ItemTypes {
        item def Air {
            attribute oxygenFraction : Percentage := 21.0;
            attribute nitrogenFraction : Percentage := 78.0;
            attribute otherFraction : Percentage := 1.0;
        }
        item def CompressedAir {
            attribute pressure : Pressure;
            attribute temperature : Temperature;
            attribute oxygenFraction : Percentage := 21.0;
        }
        item def ConcentratedOxygen {
            attribute purity : Percentage;
            attribute flowRate : VolumeFlowRate;
            attribute pressure : Pressure;
        }
        item def WasteGas {
            attribute nitrogenFraction : Percentage := 90.0;
        }
        item def ElectricalPower {
            attribute voltage : Voltage;
            attribute current : Current;
        }
        item def AlarmSignal {
            attribute alarmType : String;
            attribute severity : String;
            attribute timestamp : Duration;
        }
        item def SensorReading {
            attribute sensorType : String;
            attribute value : Real;
            attribute unit : String;
            attribute timestamp : Duration;
        }
        item def UICommand {
            attribute commandType : String;
            attribute parameter : Real;
        }
        item def UIDisplayData {
            attribute flowSetting : VolumeFlowRate;
            attribute purity : Percentage;
            attribute batteryLevel : Percentage;
            attribute statusMessage : String;
            attribute alarmActive : Boolean;
        }
    }

    package PortDefs {
        port def AirFlowPort {
            in item air : ItemTypes::Air;
        }
        port def CompressedAirPort {
            in item compressedAir : ItemTypes::CompressedAir;
        }
        port def OxygenFlowPort {
            in item oxygen : ItemTypes::ConcentratedOxygen;
        }
        port def WastePort {
            in item waste : ItemTypes::WasteGas;
        }
        port def PowerPort {
            in item power : ItemTypes::ElectricalPower;
        }
        port def SensorDataPort {
            out item reading : ItemTypes::SensorReading;
        }
        port def AlarmPort {
            out item alarm : ItemTypes::AlarmSignal;
        }
        port def UIPort {
            in item command : ItemTypes::UICommand;
            out item displayData : ItemTypes::UIDisplayData;
        }
        port def ControlPort {
            out attribute flowSetting : ValueTypes::VolumeFlowRate;
            out attribute enable : Boolean;
        }
    }

    package Components {

        part def FilteredIntake {
            port airIn : PortDefs::AirFlowPort;
            port airOut : ~PortDefs::AirFlowPort;
            attribute filterEfficiency : Percentage := 99.5;
            attribute intakeDiameter : Real := 25.0;
            perform action drawAir {
                in item ambientAir : ItemTypes::Air;
                out item filteredAir : ItemTypes::Air;
            }
        }

        part def Compressor {
            port airIn : PortDefs::AirFlowPort;
            port airOut : ~PortDefs::CompressedAirPort;
            port powerIn : PortDefs::PowerPort;
            attribute maxPressure : Pressure := 140.0;
            attribute nominalPower : Power := 55.0;
            attribute noiseLevel : SoundLevel := 42.0;
            attribute dutyCycle : Percentage := 100.0;
            perform action compress {
                in item inputAir : ItemTypes::Air;
                in item power : ItemTypes::ElectricalPower;
                out item compressedAir : ItemTypes::CompressedAir;
            }
        }

        part def SieveBed {
            port airIn : PortDefs::CompressedAirPort;
            port oxygenOut : ~PortDefs::OxygenFlowPort;
            port wasteOut : ~PortDefs::WastePort;
            attribute zeoliteMass : Mass := 0.3;
            attribute cycleTime : Duration := 8.0;
            attribute bedId : String;
            attribute isAdsorbing : Boolean;
            perform action adsorb {
                in item compressedAir : ItemTypes::CompressedAir;
                out item oxygen : ItemTypes::ConcentratedOxygen;
            }
            perform action desorb {
                out item waste : ItemTypes::WasteGas;
            }
            state bedCycle {
                entry; then Adsorbing;
                state Adsorbing {
                    do action adsorb;
                }
                state Desorbing {
                    do action desorb;
                }
                transition from Adsorbing to Desorbing when cycleTimeElapsed;
                transition from Desorbing to Adsorbing when cycleTimeElapsed;
            }
        }

        part def MolecularSieveUnit {
            port airIn : PortDefs::CompressedAirPort;
            port oxygenOut : ~PortDefs::OxygenFlowPort;
            port wasteOut : ~PortDefs::WastePort;
            part bedA : SieveBed {
                attribute bedId := 'A';
                attribute isAdsorbing := true;
            }
            part bedB : SieveBed {
                attribute bedId := 'B';
                attribute isAdsorbing := false;
            }
            attribute cycleTime : Duration := 8.0;
            attribute targetPurity : Percentage := 93.0;
            perform action pressureSwingAdsorption {
                in item compressedAir : ItemTypes::CompressedAir;
                out item oxygen : ItemTypes::ConcentratedOxygen;
                out item waste : ItemTypes::WasteGas;
            }
            connection bedA.oxygenOut flow oxygen to oxygenOut;
            connection bedB.oxygenOut flow oxygen to oxygenOut;
            connection bedA.wasteOut flow waste to wasteOut;
            connection bedB.wasteOut flow waste to wasteOut;
        }

        part def AccumulatorTank {
            port oxygenIn : PortDefs::OxygenFlowPort;
            port oxygenOut : ~PortDefs::OxygenFlowPort;
            attribute tankVolume : Real := 0.4;
            attribute maxPressure : Pressure := 80.0;
            attribute currentPressure : Pressure;
            perform action buffer {
                in item inputOxygen : ItemTypes::ConcentratedOxygen;
                out item outputOxygen : ItemTypes::ConcentratedOxygen;
            }
        }

        part def FlowRegulator {
            port oxygenIn : PortDefs::OxygenFlowPort;
            port oxygenOut : ~PortDefs::OxygenFlowPort;
            port controlIn : PortDefs::ControlPort;
            attribute minFlowRate : VolumeFlowRate := 0.5;
            attribute maxFlowRate : VolumeFlowRate := 5.0;
            attribute currentFlowSetting : VolumeFlowRate := 2.0;
            attribute stepSize : VolumeFlowRate := 0.5;
            perform action regulateFlow {
                in item inputOxygen : ItemTypes::ConcentratedOxygen;
                in attribute setting : VolumeFlowRate;
                out item outputOxygen : ItemTypes::ConcentratedOxygen;
            }
        }

        part def BatteryPack {
            port powerOut : ~PortDefs::PowerPort;
            port chargeIn : PortDefs::PowerPort;
            attribute capacity : Energy := 98.0;
            attribute currentCharge : Energy := 98.0;
            attribute chargeLevel : Percentage := 100.0;
            attribute nominalVoltage : Voltage := 14.4;
            attribute maxDischargeCurrent : Current := 5.0;
            attribute cycleCount : Integer := 0;
            perform action discharge {
                out item power : ItemTypes::ElectricalPower;
            }
            perform action charge {
                in item power : ItemTypes::ElectricalPower;
            }
            state batteryState {
                entry; then Charging;
                state Charging {
                    do action charge;
                }
                state Idle;
                state Discharging {
                    do action discharge;
                }
                transition from Charging to Idle when chargeComplete;
                transition from Idle to Discharging when loadDetected;
                transition from Discharging to Idle when loadRemoved;
                transition from Idle to Charging when chargerConnected;
            }
        }

        part def ChargingController {
            port acIn : PortDefs::PowerPort;
            port batteryPort : PortDefs::PowerPort;
            port systemPowerOut : ~PortDefs::PowerPort;
            attribute chargeCurrent : Current := 2.0;
            attribute floatVoltage : Voltage := 14.4;
            attribute temperatureCompensation : Boolean := true;
            perform action manageCharging {
                in item acPower : ItemTypes::ElectricalPower;
                out item systemPower : ItemTypes::ElectricalPower;
                out item chargePower : ItemTypes::ElectricalPower;
            }
            perform action monitorBatteryHealth {
                out attribute health : Percentage;
            }
        }

        part def PowerManagementSystem {
            port acIn : PortDefs::PowerPort;
            port systemPowerOut : ~PortDefs::PowerPort;
            part charger : ChargingController;
            part battery : BatteryPack;
            attribute activeSource : String := 'AC';
            attribute batteryRuntime : Duration;
            perform action selectSource {
                in item acPower : ItemTypes::ElectricalPower;
                out item systemPower : ItemTypes::ElectricalPower;
            }
            perform action switchToBattery {
                out item systemPower : ItemTypes::ElectricalPower;
            }
            connection acIn flow power to charger.acIn;
            connection charger.systemPowerOut flow power to systemPowerOut;
            connection charger.batteryPort flow power to battery.chargeIn;
            connection battery.powerOut flow power to systemPowerOut;
        }

        part def OxygenPuritySensor {
            port readingOut : PortDefs::SensorDataPort;
            attribute measurementRange : Percentage := 100.0;
            attribute accuracy : Percentage := 2.0;
            perform action measurePurity {
                out item reading : ItemTypes::SensorReading;
            }
        }

        part def FlowRateSensor {
            port readingOut : PortDefs::SensorDataPort;
            attribute maxRange : VolumeFlowRate := 10.0;
            attribute accuracy : VolumeFlowRate := 0.1;
            perform action measureFlow {
                out item reading : ItemTypes::SensorReading;
            }
        }

        part def PressureSensor {
            port readingOut : PortDefs::SensorDataPort;
            attribute maxRange : Pressure := 200.0;
            attribute accuracy : Pressure := 2.0;
            perform action measurePressure {
                out item reading : ItemTypes::SensorReading;
            }
        }

        part def TemperatureSensor {
            port readingOut : PortDefs::SensorDataPort;
            attribute maxRange : Temperature := 80.0;
            attribute accuracy : Temperature := 1.0;
            perform action measureTemperature {
                out item reading : ItemTypes::SensorReading;
            }
        }

        part def SensorArray {
            port readingsOut : PortDefs::SensorDataPort;
            part puritySensor : OxygenPuritySensor;
            part flowSensor : FlowRateSensor;
            part pressureSensor : PressureSensor;
            part temperatureSensor : TemperatureSensor;
            attribute samplingInterval : Duration := 1.0;
            perform action collectReadings {
                out item readings : ItemTypes::SensorReading[*];
            }
            connection puritySensor.readingOut flow reading to readingsOut;
            connection flowSensor.readingOut flow reading to readingsOut;
            connection pressureSensor.readingOut flow reading to readingsOut;
            connection temperatureSensor.readingOut flow reading to readingsOut;
        }

        part def LCDScreen {
            port displayIn : PortDefs::UIPort;
            attribute resolution : String := '128x64';
            attribute backlightEnabled : Boolean := true;
            attribute contrast : Percentage := 70.0;
            perform action display {
                in item data : ItemTypes::UIDisplayData;
            }
        }

        part def ControlButtons {
            port commandOut : ~PortDefs::UIPort;
            attribute buttonCount : Integer := 4;
            attribute buttonLabels : String[4] := ('Power', 'FlowUp', 'FlowDown', 'AlarmReset');
            perform action acceptInput {
                out item command : ItemTypes::UICommand;
            }
        }

        part def UserInterfacePanel {
            port uiPort : PortDefs::UIPort;
            part lcd : LCDScreen;
            part buttons : ControlButtons;
            perform action updateDisplay {
                in item data : ItemTypes::UIDisplayData;
            }
            perform action processCommand {
                in item command : ItemTypes::UICommand;
                out item data : ItemTypes::UIDisplayData;
            }
            connection buttons.commandOut flow command to uiPort;
            connection uiPort flow displayData to lcd.displayIn;
        }

        part def AudibleAlarm {
            port alarmIn : PortDefs::AlarmPort;
            attribute volume : SoundLevel := 70.0;
            attribute toneFrequency : Real := 2500.0;
            perform action sound {
                in item alarm : ItemTypes::AlarmSignal;
            }
        }

        part def VisualAlarm {
            port alarmIn : PortDefs::AlarmPort;
            attribute ledColor : String := 'Red';
            attribute flashRate : Real := 2.0;
            perform action flash {
                in item alarm : ItemTypes::AlarmSignal;
            }
        }

        part def AlarmSubsystem {
            port alarmOut : PortDefs::AlarmPort;
            part buzzer : AudibleAlarm;
            part indicator : VisualAlarm;
            attribute alarmThresholds;
            attribute lowPurityThreshold : Percentage := 85.0;
            attribute lowBatteryThreshold : Percentage := 20.0;
            attribute highPressureThreshold : Pressure := 160.0;
            attribute highTempThreshold : Temperature := 60.0;
            perform action triggerAlarm {
                in attribute condition : String;
                out item alarm : ItemTypes::AlarmSignal;
            }
            perform action clearAlarm {
                out item alarm : ItemTypes::AlarmSignal;
            }
            connection alarmOut flow alarm to buzzer.alarmIn;
            connection alarmOut flow alarm to indicator.alarmIn;
        }

        part def CentralControllerBoard {
            port sensorIn : PortDefs::SensorDataPort;
            port uiPort : PortDefs::UIPort;
            port alarmPort : ~PortDefs::AlarmPort;
            port controlOut : ~PortDefs::ControlPort;
            port powerIn : PortDefs::PowerPort;
            attribute clockSpeed : Real := 48.0;
            attribute firmwareVersion : String := '1.2.0';
            attribute watchdogTimeout : Duration := 5.0;
            perform action monitorSystem {
                in item readings : ItemTypes::SensorReading[*];
                out item commands : String[*];
            }
            perform action evaluateSafety {
                in item readings : ItemTypes::SensorReading[*];
                out item alarm : ItemTypes::AlarmSignal;
            }
            perform action adjustFlow {
                in item command : ItemTypes::UICommand;
                out attribute setting : VolumeFlowRate;
            }
            perform action runDiagnostics {
                out attribute status : String;
            }
        }
    }

    package SystemModel {

        part def PortableOxygenConcentrator {
            attribute totalMass : ValueTypes::Mass := 2.8;
            attribute maxNoiseLevel : ValueTypes::SoundLevel := 45.0;
            attribute dimensions : String := '300x200x150 mm';
            attribute targetOxygenPurity : ValueTypes::Percentage := 93.0;
            attribute flowRangeMin : ValueTypes::VolumeFlowRate := 0.5;
            attribute flowRangeMax : ValueTypes::VolumeFlowRate := 5.0;
            attribute batteryRuntime : ValueTypes::Duration := 10800.0;

            port ambientAirIntake : PortDefs::AirFlowPort;
            port patientOutput : ~PortDefs::OxygenFlowPort;
            port acPowerInput : PortDefs::PowerPort;
            port userInterface : PortDefs::UIPort;

            part intake : Components::FilteredIntake;
            part compressor : Components::Compressor;
            part sieve : Components::MolecularSieveUnit;
            part accumulator : Components::AccumulatorTank;
            part flowRegulator : Components::FlowRegulator;
            part powerSystem : Components::PowerManagementSystem;
            part sensors : Components::SensorArray;
            part uiPanel : Components::UserInterfacePanel;
            part alarms : Components::AlarmSubsystem;
            part controller : Components::CentralControllerBoard;

            connection ambientAirIntake flow air to intake.airIn;
            connection intake.airOut flow air to compressor.airIn;
            connection compressor.airOut flow compressedAir to sieve.airIn;
            connection sieve.oxygenOut flow oxygen to accumulator.oxygenIn;
            connection accumulator.oxygenOut flow oxygen to flowRegulator.oxygenIn;
            connection flowRegulator.oxygenOut flow oxygen to patientOutput;
            connection acPowerInput flow power to powerSystem.acIn;
            connection powerSystem.systemPowerOut flow power to compressor.powerIn;
            connection powerSystem.systemPowerOut flow power to controller.powerIn;
            connection sensors.readingsOut flow reading to controller.sensorIn;
            connection uiPanel.uiPort to controller.uiPort;
            connection controller.alarmPort to alarms.alarmOut;
            connection controller.controlOut to flowRegulator.controlIn;
            connection userInterface to uiPanel.uiPort;

            perform action deliverOxygen {
                in item ambientAir : ItemTypes::Air;
                in item power : ItemTypes::ElectricalPower;
                out item oxygen : ItemTypes::ConcentratedOxygen;
            }
            perform action systemChecks {
                out attribute checksPassed : Boolean;
            }
            perform action alertUser {
                in item alarm : ItemTypes::AlarmSignal;
            }
            perform action safeShutdown {
                out attribute shutdownComplete : Boolean;
            }
            perform action powerOffAction;
            perform action standbyEntry;

            state deviceOperation {
                entry; then PoweredOff;

                state PoweredOff {
                    entry action powerOffAction;
                }
                state Standby {
                    entry action standbyEntry;
                    do action systemChecks;
                }
                state Operational {
                    do action deliverOxygen;
                }
                state AlarmState {
                    do action alertUser;
                }
                state FaultState {
                    do action safeShutdown;
                }

                transition from PoweredOff to Standby when powerOn;
                transition from Standby to Operational when checksPassed;
                transition from Standby to FaultState when checksFailed;
                transition from Operational to AlarmState when alarmCondition;
                transition from AlarmState to Operational when alarmCleared;
                transition from AlarmState to FaultState when faultDetected;
                transition from Operational to PoweredOff when powerOff;
                transition from Standby to PoweredOff when powerOff;
                transition from AlarmState to PoweredOff when powerOff;
                transition from FaultState to PoweredOff when reset;
            }
        }
    }

    package Requirements {

        requirement def OxygenPurityRequirement {
            doc /* The concentrator shall deliver medical-grade oxygen with purity of at least 90%. */
            subject concentrator : SystemModel::PortableOxygenConcentrator;
            constraint { concentrator.targetOxygenPurity >= 90.0 }
        }

        requirement def FlowRateRangeRequirement {
            doc /* The device shall allow flow rate adjustment from 0.5 to 5.0 L/min in 0.5 L/min increments. */
            subject concentrator : SystemModel::PortableOxygenConcentrator;
            constraint { concentrator.flowRangeMin == 0.5 and concentrator.flowRangeMax == 5.0 }
        }

        requirement def MassRequirement {
            doc /* The total device mass shall be less than 3 kg for portability. */
            subject concentrator : SystemModel::PortableOxygenConcentrator;
            constraint { concentrator.totalMass < 3.0 }
        }

        requirement def NoiseRequirement {
            doc /* The device noise level shall not exceed 45 dB during operation. */
            subject concentrator : SystemModel::PortableOxygenConcentrator;
            constraint { concentrator.maxNoiseLevel <= 45.0 }
        }

        requirement def DualPowerRequirement {
            doc /* The device shall operate from AC mains and from an internal rechargeable battery. */
            subject powerSystem : Components::PowerManagementSystem;
        }

        requirement def BatteryRuntimeRequirement {
            doc /* The battery shall provide at least 3 hours of operation at 2 L/min. */
            subject battery : Components::BatteryPack;
            constraint { battery.capacity >= 90.0 }
        }

        requirement def AlarmRequirement {
            doc /* The device shall provide audible and visual alarms for low purity, low battery, high pressure, and system malfunction. */
            subject alarms : Components::AlarmSubsystem;
        }

        requirement def ContinuousOxygenRequirement {
            doc /* The molecular sieve shall produce continuous oxygen via alternating two-bed pressure swing adsorption. */
            subject sieve : Components::MolecularSieveUnit;
        }

        requirement def SensorMonitoringRequirement {
            doc /* The controller shall monitor oxygen purity, flow rate, internal pressure, and temperature. */
            subject sensors : Components::SensorArray;
        }

        requirement def UserInterfaceRequirement {
            doc /* The device shall include an LCD screen and buttons for operation and flow adjustment. */
            subject ui : Components::UserInterfacePanel;
        }

        requirement def StateMachineRequirement {
            doc /* The device shall operate through PoweredOff, Standby, Operational, Alarm, and Fault states. */
            subject concentrator : SystemModel::PortableOxygenConcentrator;
        }

        requirement OxygenPurityReq : OxygenPurityRequirement;
        requirement FlowRateRangeReq : FlowRateRangeRequirement;
        requirement MassReq : MassRequirement;
        requirement NoiseReq : NoiseRequirement;
        requirement DualPowerReq : DualPowerRequirement;
        requirement BatteryRuntimeReq : BatteryRuntimeRequirement;
        requirement AlarmReq : AlarmRequirement;
        requirement ContinuousOxygenReq : ContinuousOxygenRequirement;
        requirement SensorMonitoringReq : SensorMonitoringRequirement;
        requirement UserInterfaceReq : UserInterfaceRequirement;
        requirement StateMachineReq : StateMachineRequirement;

        satisfaction OxygenPurityReq satisfy SystemModel::PortableOxygenConcentrator::targetOxygenPurity;
        satisfaction MassReq satisfy SystemModel::PortableOxygenConcentrator::totalMass;
        satisfaction NoiseReq satisfy SystemModel::PortableOxygenConcentrator::maxNoiseLevel;
    }
}
