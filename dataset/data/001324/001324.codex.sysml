package SmartHouseModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Celsius :> Real {
        unit = "degC";
    }

    attribute def Percent :> Real {
        unit = "%";
    }

    attribute def Lux :> Real {
        unit = "lx";
    }

    attribute def Watt :> Real {
        unit = "W";
    }

    attribute def KilowattHour :> Real {
        unit = "kWh";
    }

    attribute def Volt :> Real {
        unit = "V";
    }

    attribute def Ampere :> Real {
        unit = "A";
    }

    attribute def Minute :> Real {
        unit = "min";
    }

    attribute def Ppm :> Real {
        unit = "ppm";
    }

    attribute def BooleanStatus :> Boolean;

    item def ElectricalPower {
        attribute voltage : Volt;
        attribute current : Ampere;
        attribute realPower : Watt;
    }

    item def ThermalAir {
        attribute temperature : Celsius;
        attribute relativeHumidity : Percent;
        attribute co2Concentration : Ppm;
    }

    item def OccupancySignal {
        attribute occupied : BooleanStatus;
        attribute occupantCount : Integer;
        attribute confidence : Percent;
    }

    item def SecurityEvent {
        attribute intrusionDetected : BooleanStatus;
        attribute smokeDetected : BooleanStatus;
        attribute waterLeakDetected : BooleanStatus;
        attribute severity : Integer;
    }

    item def ControlCommand {
        attribute commandId : String;
        attribute targetDevice : String;
        attribute requestedState : String;
        attribute priority : Integer;
    }

    item def HouseStatus {
        attribute indoorTemperature : Celsius;
        attribute indoorHumidity : Percent;
        attribute occupancyCount : Integer;
        attribute activeAlarm : BooleanStatus;
        attribute currentPowerUse : Watt;
        attribute dailyEnergyUse : KilowattHour;
    }

    port def PowerInPort {
        in item power : ElectricalPower;
    }

    port def PowerOutPort {
        out item power : ElectricalPower;
    }

    port def AirSensePort {
        out item air : ThermalAir;
    }

    port def OccupancySensePort {
        out item occupancy : OccupancySignal;
    }

    port def SecuritySensePort {
        out item event : SecurityEvent;
    }

    port def CommandInPort {
        in item command : ControlCommand;
    }

    port def CommandOutPort {
        out item command : ControlCommand;
    }

    port def StatusOutPort {
        out item status : HouseStatus;
    }

    port def NetworkPort {
        in item inboundCommand : ControlCommand;
        out item outboundStatus : HouseStatus;
    }

    part def SmartHouse {
        doc /* Primary high-level function:
               The SmartHouse continuously monitors occupancy, comfort, safety, and energy conditions,
               then automatically coordinates heating, cooling, lighting, security, appliances, and
               user notifications to maintain a safe, comfortable, and energy-efficient living environment. */

        attribute targetTemperature : Celsius = 21.0;
        attribute ecoTemperature : Celsius = 17.0;
        attribute maxIndoorCO2 : Ppm = 1000.0;
        attribute nightIlluminanceTarget : Lux = 80.0;
        attribute occupiedIlluminanceTarget : Lux = 350.0;
        attribute dailyEnergyBudget : KilowattHour = 32.0;
        attribute alarmArmed : BooleanStatus = true;

        port gridPower : PowerInPort;
        port cloudLink : NetworkPort;
        port residentConsole : NetworkPort;
        port houseStatus : StatusOutPort;

        part energySystem : EnergyManagementSystem;
        part climateSystem : ClimateControlSystem;
        part lightingSystem : LightingControlSystem;
        part securitySystem : SecurityAndSafetySystem;
        part applianceSystem : ApplianceManagementSystem;
        part userInterface : ResidentInterface;
        part automationController : HomeAutomationController;

        connect gridPower.power to energySystem.utilityInput.power;
        connect energySystem.conditionedPower.power to climateSystem.powerInput.power;
        connect energySystem.conditionedPower.power to lightingSystem.powerInput.power;
        connect energySystem.conditionedPower.power to securitySystem.powerInput.power;
        connect energySystem.conditionedPower.power to applianceSystem.powerInput.power;
        connect energySystem.conditionedPower.power to automationController.powerInput.power;
        connect energySystem.conditionedPower.power to userInterface.powerInput.power;

        connect climateSystem.airReport.air to automationController.airInput.air;
        connect lightingSystem.occupancyReport.occupancy to automationController.occupancyInput.occupancy;
        connect securitySystem.securityReport.event to automationController.securityInput.event;
        connect energySystem.energyStatus.status to automationController.energyInput.status;

        connect automationController.climateCommand.command to climateSystem.commandInput.command;
        connect automationController.lightingCommand.command to lightingSystem.commandInput.command;
        connect automationController.securityCommand.command to securitySystem.commandInput.command;
        connect automationController.applianceCommand.command to applianceSystem.commandInput.command;
        connect automationController.uiStatus.status to userInterface.statusInput.outboundStatus;
        connect userInterface.userCommands.inboundCommand to automationController.userCommandInput.command;

        connect automationController.cloudStatus.status to cloudLink.outboundStatus;
        connect cloudLink.inboundCommand to automationController.remoteCommandInput.command;
        connect automationController.houseStatus.status to houseStatus.status;

        action perform primaryFunction {
            first startMonitoring;
            then evaluateHouseState;
            then coordinateSubsystems;
            then reportStatus;

            action startMonitoring {
                in item air : ThermalAir;
                in item occupancy : OccupancySignal;
                in item event : SecurityEvent;
                in item power : ElectricalPower;
            }

            action evaluateHouseState {
                in item air : ThermalAir;
                in item occupancy : OccupancySignal;
                in item event : SecurityEvent;
                in item energy : HouseStatus;
                out item status : HouseStatus;
            }

            action coordinateSubsystems {
                in item status : HouseStatus;
                out item climateCommand : ControlCommand;
                out item lightingCommand : ControlCommand;
                out item securityCommand : ControlCommand;
                out item applianceCommand : ControlCommand;
            }

            action reportStatus {
                in item status : HouseStatus;
                out item publishedStatus : HouseStatus;
            }
        }

        state def OperatingStateMachine {
            state Initializing;
            state UnoccupiedEco;
            state OccupiedComfort;
            state NightSecure;
            state Emergency;
            state EnergySaving;

            transition first Initializing
                then UnoccupiedEco;

            transition UnoccupiedEco
                first accept OccupancyDetected
                then OccupiedComfort;

            transition OccupiedComfort
                first accept NoOccupancyFor30Minutes
                then UnoccupiedEco;

            transition OccupiedComfort
                first accept NightModeRequested
                then NightSecure;

            transition NightSecure
                first accept MorningOccupancyDetected
                then OccupiedComfort;

            transition OccupiedComfort
                first accept EnergyBudgetExceeded
                then EnergySaving;

            transition EnergySaving
                first accept EnergyUseNormal
                then OccupiedComfort;

            transition UnoccupiedEco
                first accept SecurityOrSafetyAlarm
                then Emergency;

            transition OccupiedComfort
                first accept SecurityOrSafetyAlarm
                then Emergency;

            transition NightSecure
                first accept SecurityOrSafetyAlarm
                then Emergency;

            transition EnergySaving
                first accept SecurityOrSafetyAlarm
                then Emergency;

            transition Emergency
                first accept AlarmClearedByResident
                then OccupiedComfort;
        }
    }

    part def HomeAutomationController {
        attribute controlCycleTime : Minute = 1.0;
        attribute occupied : BooleanStatus = false;
        attribute emergencyActive : BooleanStatus = false;
        attribute energySavingActive : BooleanStatus = false;

        port powerInput : PowerInPort;
        port airInput : AirSensePort;
        port occupancyInput : OccupancySensePort;
        port securityInput : SecuritySensePort;
        port energyInput : StatusOutPort;
        port userCommandInput : CommandInPort;
        port remoteCommandInput : CommandInPort;

        port climateCommand : CommandOutPort;
        port lightingCommand : CommandOutPort;
        port securityCommand : CommandOutPort;
        port applianceCommand : CommandOutPort;
        port uiStatus : StatusOutPort;
        port cloudStatus : StatusOutPort;
        port houseStatus : StatusOutPort;

        action def AnalyzeAndControl {
            in item air : ThermalAir;
            in item occupancy : OccupancySignal;
            in item security : SecurityEvent;
            in item userCommand : ControlCommand;
            out item climateCommand : ControlCommand;
            out item lightingCommand : ControlCommand;
            out item securityCommand : ControlCommand;
            out item applianceCommand : ControlCommand;
            out item status : HouseStatus;
        }
    }

    part def EnergyManagementSystem {
        attribute mainBusVoltage : Volt = 240.0;
        attribute maximumContinuousPower : Watt = 12000.0;
        attribute currentPowerUse : Watt;
        attribute dailyEnergyUse : KilowattHour;
        attribute solarGeneration : Watt;
        attribute batteryStateOfCharge : Percent;

        port utilityInput : PowerInPort;
        port conditionedPower : PowerOutPort;
        port energyStatus : StatusOutPort;

        part smartMeter : SmartMeter;
        part solarArray : SolarArray;
        part battery : HomeBattery;
        part loadPanel : SmartLoadPanel;

        connect utilityInput.power to smartMeter.gridPower.power;
        connect solarArray.generatedPower.power to loadPanel.solarInput.power;
        connect battery.batteryPower.power to loadPanel.batteryInput.power;
        connect smartMeter.meteredPower.power to loadPanel.gridInput.power;
        connect loadPanel.housePower.power to conditionedPower.power;

        action def OptimizeEnergyUse {
            in attribute measuredPower : Watt;
            in attribute generatedPower : Watt;
            in attribute batteryCharge : Percent;
            out item loadShedCommand : ControlCommand;
        }
    }

    part def SmartMeter {
        attribute instantaneousPower : Watt;
        attribute cumulativeEnergyToday : KilowattHour;
        port gridPower : PowerInPort;
        port meteredPower : PowerOutPort;
    }

    part def SolarArray {
        attribute ratedPower : Watt = 6500.0;
        attribute currentGeneration : Watt;
        port generatedPower : PowerOutPort;
    }

    part def HomeBattery {
        attribute usableCapacity : KilowattHour = 13.5;
        attribute stateOfCharge : Percent;
        attribute maxDischargePower : Watt = 5000.0;
        port batteryPower : PowerOutPort;
    }

    part def SmartLoadPanel {
        attribute criticalLoadPower : Watt;
        attribute discretionaryLoadPower : Watt;
        port gridInput : PowerInPort;
        port solarInput : PowerInPort;
        port batteryInput : PowerInPort;
        port housePower : PowerOutPort;
    }

    part def ClimateControlSystem {
        attribute heatingSetpoint : Celsius = 21.0;
        attribute coolingSetpoint : Celsius = 24.0;
        attribute ecoSetpoint : Celsius = 17.0;
        attribute fanSpeedPercent : Percent;
        attribute indoorTemperature : Celsius;
        attribute indoorHumidity : Percent;

        port powerInput : PowerInPort;
        port commandInput : CommandInPort;
        port airReport : AirSensePort;

        part thermostat : SmartThermostat;
        part heatPump : HeatPump;
        part ventilator : EnergyRecoveryVentilator;
        part humidityController : HumidityController;
        part airQualitySensor : IndoorAirQualitySensor;

        connect powerInput.power to thermostat.powerInput.power;
        connect powerInput.power to heatPump.powerInput.power;
        connect powerInput.power to ventilator.powerInput.power;
        connect powerInput.power to humidityController.powerInput.power;

        connect thermostat.hvacCommand.command to heatPump.commandInput.command;
        connect thermostat.ventilationCommand.command to ventilator.commandInput.command;
        connect airQualitySensor.airReport.air to airReport.air;

        state def ClimateMode {
            state Off;
            state Heating;
            state Cooling;
            state Ventilating;
            state EcoHold;

            transition first Off then EcoHold;

            transition EcoHold
                first accept OccupiedComfortRequested
                then Heating;

            transition Heating
                first accept TemperatureAboveHeatingBand
                then Off;

            transition Off
                first accept TemperatureAboveCoolingSetpoint
                then Cooling;

            transition Cooling
                first accept TemperatureBelowCoolingBand
                then Off;

            transition Off
                first accept CO2AboveLimit
                then Ventilating;

            transition Ventilating
                first accept AirQualityNormal
                then Off;
        }
    }

    part def SmartThermostat {
        attribute measuredTemperature : Celsius;
        attribute measuredHumidity : Percent;
        attribute activeSetpoint : Celsius;
        port powerInput : PowerInPort;
        port hvacCommand : CommandOutPort;
        port ventilationCommand : CommandOutPort;
    }

    part def HeatPump {
        attribute ratedHeatingPower : Watt = 4200.0;
        attribute ratedCoolingPower : Watt = 3600.0;
        attribute compressorPower : Watt;
        port powerInput : PowerInPort;
        port commandInput : CommandInPort;
    }

    part def EnergyRecoveryVentilator {
        attribute airflowRate : Real;
        attribute fanPower : Watt = 120.0;
        port powerInput : PowerInPort;
        port commandInput : CommandInPort;
    }

    part def HumidityController {
        attribute targetHumidity : Percent = 45.0;
        attribute actualHumidity : Percent;
        port powerInput : PowerInPort;
        port commandInput : CommandInPort;
    }

    part def IndoorAirQualitySensor {
        attribute temperature : Celsius;
        attribute humidity : Percent;
        attribute co2 : Ppm;
        port airReport : AirSensePort;
    }

    part def LightingControlSystem {
        attribute defaultOccupiedIlluminance : Lux = 350.0;
        attribute nightPathIlluminance : Lux = 80.0;
        attribute totalLightingPower : Watt;

        port powerInput : PowerInPort;
        port commandInput : CommandInPort;
        port occupancyReport : OccupancySensePort;

        part occupancySensors : OccupancySensor[6];
        part daylightSensors : DaylightSensor[4];
        part dimmableFixtures : SmartLightFixture[24];
        part exteriorLights : SmartLightFixture[8];

        action def AdjustLighting {
            in item occupancy : OccupancySignal;
            in attribute daylightLevel : Lux;
            out item fixtureCommand : ControlCommand;
        }
    }

    part def OccupancySensor {
        attribute detected : BooleanStatus;
        attribute occupantCountEstimate : Integer;
        attribute confidence : Percent;
        port occupancyReport : OccupancySensePort;
    }

    part def DaylightSensor {
        attribute measuredIlluminance : Lux;
    }

    part def SmartLightFixture {
        attribute dimLevel : Percent;
        attribute colorTemperature : Real;
        attribute ratedPower : Watt = 12.0;
        port powerInput : PowerInPort;
        port commandInput : CommandInPort;
    }

    part def SecurityAndSafetySystem {
        attribute armed : BooleanStatus = true;
        attribute alarmActive : BooleanStatus = false;
        attribute cameraRecording : BooleanStatus = false;

        port powerInput : PowerInPort;
        port commandInput : CommandInPort;
        port securityReport : SecuritySensePort;

        part doorSensors : DoorWindowSensor[12];
        part motionSensors : OccupancySensor[8];
        part smokeDetectors : SmokeDetector[6];
        part leakSensors : WaterLeakSensor[5];
        part smartLocks : SmartDoorLock[3];
        part cameras : SecurityCamera[5];
        part siren : AlarmSiren;

        connect powerInput.power to siren.powerInput.power;

        state def SecurityMode {
            state Disarmed;
            state ArmedStay;
            state ArmedAway;
            state Alarm;

            transition first Disarmed then ArmedStay;

            transition Disarmed
                first accept ArmAwayCommand
                then ArmedAway;

            transition ArmedStay
                first accept ArmAwayCommand
                then ArmedAway;

            transition ArmedAway
                first accept ValidResidentUnlock
                then Disarmed;

            transition ArmedAway
                first accept IntrusionDetected
                then Alarm;

            transition ArmedStay
                first accept PerimeterBreach
                then Alarm;

            transition Alarm
                first accept VerifiedResidentReset
                then Disarmed;
        }
    }

    part def DoorWindowSensor {
        attribute open : BooleanStatus;
        attribute tamperDetected : BooleanStatus;
        port securityReport : SecuritySensePort;
    }

    part def SmokeDetector {
        attribute smokeDetected : BooleanStatus;
        attribute batteryPercent : Percent;
        port securityReport : SecuritySensePort;
    }

    part def WaterLeakSensor {
        attribute wet : BooleanStatus;
        attribute batteryPercent : Percent;
        port securityReport : SecuritySensePort;
    }

    part def SmartDoorLock {
        attribute locked : BooleanStatus;
        attribute batteryPercent : Percent;
        port powerInput : PowerInPort;
        port commandInput : CommandInPort;
    }

    part def SecurityCamera {
        attribute recording : BooleanStatus;
        attribute motionDetected : BooleanStatus;
        attribute powerUse : Watt = 8.0;
        port powerInput : PowerInPort;
        port commandInput : CommandInPort;
    }

    part def AlarmSiren {
        attribute soundPressureLevel : Real = 105.0;
        attribute active : BooleanStatus;
        port powerInput : PowerInPort;
        port commandInput : CommandInPort;
    }

    part def ApplianceManagementSystem {
        attribute controllableLoadPower : Watt;
        attribute deferredLoadEnergy : KilowattHour;

        port powerInput : PowerInPort;
        port commandInput : CommandInPort;

        part refrigerator : ManagedAppliance {
            attribute ratedPower : Watt = 180.0;
            attribute criticalLoad : BooleanStatus = true;
        }

        part washer : ManagedAppliance {
            attribute ratedPower : Watt = 900.0;
            attribute criticalLoad : BooleanStatus = false;
        }

        part dryer : ManagedAppliance {
            attribute ratedPower : Watt = 4200.0;
            attribute criticalLoad : BooleanStatus = false;
        }

        part dishwasher : ManagedAppliance {
            attribute ratedPower : Watt = 1500.0;
            attribute criticalLoad : BooleanStatus = false;
        }

        part waterHeater : ManagedAppliance {
            attribute ratedPower : Watt = 4500.0;
            attribute criticalLoad : BooleanStatus = true;
        }
    }

    part def ManagedAppliance {
        attribute ratedPower : Watt;
        attribute activePower : Watt;
        attribute criticalLoad : BooleanStatus;
        attribute enabled : BooleanStatus;
        port powerInput : PowerInPort;
        port commandInput : CommandInPort;
    }

    part def ResidentInterface {
        attribute localDisplayActive : BooleanStatus;
        attribute remoteAccessEnabled : BooleanStatus = true;

        port powerInput : PowerInPort;
        port userCommands : NetworkPort;
        port statusInput : NetworkPort;

        part wallPanel : WallControlPanel;
        part mobileAppGateway : MobileAppGateway;
        part notificationService : NotificationService;
    }

    part def WallControlPanel {
        attribute screenBrightness : Percent;
        port powerInput : PowerInPort;
        port commandOutput : CommandOutPort;
        port statusInput : StatusOutPort;
    }

    part def MobileAppGateway {
        attribute connected : BooleanStatus;
        attribute latencyMs : Real;
        port remoteCommands : CommandInPort;
        port remoteStatus : StatusOutPort;
    }

    part def NotificationService {
        attribute pendingAlerts : Integer;
        port alertInput : SecuritySensePort;
        port statusInput : StatusOutPort;
    }

    requirement def MaintainComfortRequirement {
        doc /* While the home is occupied and no emergency mode is active, the smart house shall maintain indoor temperature within 2 degC of the resident comfort setpoint. */
        attribute maximumTemperatureError : Celsius = 2.0;
    }

    requirement def ReduceEnergyUseRequirement {
        doc /* The smart house shall reduce discretionary electrical loads when daily energy use exceeds the configured daily energy budget. */
        attribute dailyBudget : KilowattHour = 32.0;
    }

    requirement def DetectSafetyHazardsRequirement {
        doc /* The smart house shall detect smoke, water leak, and intrusion events and publish an alarm status to resident interfaces. */
        attribute maximumAlarmNotificationDelay : Minute = 1.0;
    }

    requirement def SupportRemoteMonitoringRequirement {
        doc /* The smart house shall provide current house status to authorized remote users. */
        attribute maximumStatusAge : Minute = 1.0;
    }

    requirement def PreserveCriticalLoadsRequirement {
        doc /* During energy-saving operation, the smart house shall preserve power to critical loads including refrigeration, safety sensors, network access, and door locks. */
    }

    satisfy MaintainComfortRequirement by SmartHouse::climateSystem;
    satisfy ReduceEnergyUseRequirement by SmartHouse::energySystem;
    satisfy DetectSafetyHazardsRequirement by SmartHouse::securitySystem;
    satisfy SupportRemoteMonitoringRequirement by SmartHouse::userInterface;
    satisfy PreserveCriticalLoadsRequirement by SmartHouse::energySystem;

    exhibit state SmartHouse::OperatingStateMachine by SmartHouse;
}