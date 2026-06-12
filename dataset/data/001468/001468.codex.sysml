package IndoorAirQualitySystemModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Temperature :> Real {
        unit = "degC";
    }

    attribute def RelativeHumidity :> Real {
        unit = "%";
    }

    attribute def ConcentrationCO2 :> Real {
        unit = "ppm";
    }

    attribute def ConcentrationVOC :> Real {
        unit = "ppb";
    }

    attribute def ParticleConcentration :> Real {
        unit = "ug/m3";
    }

    attribute def AirflowRate :> Real {
        unit = "m3/h";
    }

    attribute def PressureDifference :> Real {
        unit = "Pa";
    }

    attribute def ElectricPower :> Real {
        unit = "W";
    }

    attribute def TimeDuration :> Real {
        unit = "s";
    }

    enum def AirQualityLevel {
        enum excellent;
        enum acceptable;
        enum degraded;
        enum unhealthy;
        enum critical;
    }

    enum def OperatingMode {
        enum standby;
        enum monitorOnly;
        enum ventilate;
        enum filter;
        enum purge;
        enum faultSafe;
    }

    enum def OccupancyState {
        enum unoccupied;
        enum occupied;
    }

    item def IndoorAir {
        attribute temperature : Temperature;
        attribute relativeHumidity : RelativeHumidity;
        attribute co2 : ConcentrationCO2;
        attribute voc : ConcentrationVOC;
        attribute pm25 : ParticleConcentration;
        attribute qualityLevel : AirQualityLevel;
    }

    item def OutdoorAir {
        attribute temperature : Temperature;
        attribute relativeHumidity : RelativeHumidity;
        attribute pm25 : ParticleConcentration;
    }

    item def FilteredAir {
        attribute airflow : AirflowRate;
        attribute pm25 : ParticleConcentration;
        attribute voc : ConcentrationVOC;
    }

    item def SensorSample {
        attribute sampledTemperature : Temperature;
        attribute sampledHumidity : RelativeHumidity;
        attribute sampledCO2 : ConcentrationCO2;
        attribute sampledVOC : ConcentrationVOC;
        attribute sampledPM25 : ParticleConcentration;
        attribute sampleAge : TimeDuration;
    }

    item def AirQualityCommand {
        attribute requestedMode : OperatingMode;
        attribute targetVentilationRate : AirflowRate;
        attribute targetFanPower : ElectricPower;
    }

    item def MaintenanceAlert {
        attribute filterReplacementRequired : Boolean;
        attribute sensorFaultDetected : Boolean;
        attribute actuatorFaultDetected : Boolean;
    }

    port def AirIntakePort {
        in item incomingAir : OutdoorAir;
    }

    port def RoomAirPort {
        inout item roomAir : IndoorAir;
    }

    port def SupplyAirPort {
        out item suppliedAir : FilteredAir;
    }

    port def ExhaustAirPort {
        out item exhaustedAir : IndoorAir;
    }

    port def SamplePort {
        out item sample : SensorSample;
    }

    port def CommandPort {
        in item command : AirQualityCommand;
    }

    port def AlertPort {
        out item alert : MaintenanceAlert;
    }

    part def MultiSensorModule {
        port roomAirPort : RoomAirPort;
        port samplePort : SamplePort;

        attribute measurementPeriod : TimeDuration = 10.0;
        attribute co2Accuracy : ConcentrationCO2 = 50.0;
        attribute pm25Accuracy : ParticleConcentration = 2.0;
        attribute vocAccuracy : ConcentrationVOC = 20.0;

        action senseIndoorAir {
            in item air : IndoorAir;
            out item sample : SensorSample;

            first start;
            then readTemperature;
            then readHumidity;
            then readCO2;
            then readVOC;
            then readPM25;
            then publishSample;
            then done;

            action readTemperature;
            action readHumidity;
            action readCO2;
            action readVOC;
            action readPM25;
            action publishSample;
        }
    }

    part def AirQualityController {
        port sampleInput : SamplePort;
        port commandOutput : CommandPort;
        port alertOutput : AlertPort;

        attribute co2LimitAcceptable : ConcentrationCO2 = 900.0;
        attribute co2LimitUnhealthy : ConcentrationCO2 = 1400.0;
        attribute vocLimitAcceptable : ConcentrationVOC = 300.0;
        attribute vocLimitUnhealthy : ConcentrationVOC = 800.0;
        attribute pm25LimitAcceptable : ParticleConcentration = 12.0;
        attribute pm25LimitUnhealthy : ParticleConcentration = 35.0;
        attribute minimumVentilationRate : AirflowRate = 80.0;
        attribute purgeVentilationRate : AirflowRate = 350.0;
        attribute currentMode : OperatingMode;
        attribute assessedQuality : AirQualityLevel;

        action classifyAirQuality {
            in item sample : SensorSample;
            out attribute quality : AirQualityLevel;

            first evaluateCO2;
            then evaluateVOC;
            then evaluatePM25;
            then selectWorstCategory;
            then done;

            action evaluateCO2;
            action evaluateVOC;
            action evaluatePM25;
            action selectWorstCategory;
        }

        action computeControlCommand {
            in attribute quality : AirQualityLevel;
            in attribute occupancy : OccupancyState;
            out item command : AirQualityCommand;

            first determineMode;
            then determineAirflow;
            then determineFanPower;
            then publishCommand;
            then done;

            action determineMode;
            action determineAirflow;
            action determineFanPower;
            action publishCommand;
        }

        state def ControllerStateMachine {
            entry action initializeController;

            state initializing;
            state standby;
            state monitoring;
            state ventilating;
            state filtering;
            state purging;
            state faultSafe;

            transition first initializing then standby;
            transition standby then monitoring
                accept after 10.0;
            transition monitoring then ventilating
                if assessedQuality == AirQualityLevel::degraded;
            transition monitoring then purging
                if assessedQuality == AirQualityLevel::unhealthy or assessedQuality == AirQualityLevel::critical;
            transition ventilating then monitoring
                if assessedQuality == AirQualityLevel::acceptable or assessedQuality == AirQualityLevel::excellent;
            transition purging then filtering
                if assessedQuality == AirQualityLevel::degraded;
            transition filtering then monitoring
                if assessedQuality == AirQualityLevel::acceptable or assessedQuality == AirQualityLevel::excellent;
            transition monitoring then faultSafe
                if sampleInput.sample.sampleAge > 60.0;
            transition ventilating then faultSafe
                if sampleInput.sample.sampleAge > 60.0;
            transition purging then faultSafe
                if sampleInput.sample.sampleAge > 60.0;
            transition faultSafe then monitoring
                if sampleInput.sample.sampleAge <= 20.0;
        }
    }

    part def VentilationUnit {
        port outdoorAirIn : AirIntakePort;
        port exhaustAirOut : ExhaustAirPort;
        port supplyAirOut : SupplyAirPort;
        port commandIn : CommandPort;

        attribute maximumAirflow : AirflowRate = 400.0;
        attribute minimumAirflow : AirflowRate = 40.0;
        attribute fanPower : ElectricPower;
        attribute ductPressure : PressureDifference;

        action exchangeAir {
            in item outdoorAir : OutdoorAir;
            in item indoorAir : IndoorAir;
            in item command : AirQualityCommand;
            out item suppliedAir : FilteredAir;
            out item exhaustedAir : IndoorAir;

            first receiveCommand;
            then drawOutdoorAir;
            then exhaustIndoorAir;
            then regulateAirflow;
            then deliverSupplyAir;
            then done;

            action receiveCommand;
            action drawOutdoorAir;
            action exhaustIndoorAir;
            action regulateAirflow;
            action deliverSupplyAir;
        }
    }

    part def FiltrationModule {
        port airIn : SupplyAirPort;
        port airOut : SupplyAirPort;

        attribute hepaRemovalEfficiencyPM25 : Real = 0.97;
        attribute carbonRemovalEfficiencyVOC : Real = 0.65;
        attribute filterPressureDrop : PressureDifference;
        attribute filterLifeRemaining : Real;

        action filterAir {
            in item unfilteredAir : FilteredAir;
            out item cleanAir : FilteredAir;

            first captureParticles;
            then adsorbVOC;
            then updateFilterLife;
            then releaseCleanAir;
            then done;

            action captureParticles;
            action adsorbVOC;
            action updateFilterLife;
            action releaseCleanAir;
        }
    }

    part def RoomZone {
        port roomAirInterface : RoomAirPort;
        port supplyAirIn : SupplyAirPort;
        port exhaustAirInterface : ExhaustAirPort;

        attribute floorArea : Real = 65.0;
        attribute ceilingHeight : Real = 2.7;
        attribute occupancy : OccupancyState;
        attribute currentAir : IndoorAir;

        action mixSuppliedAir {
            in item suppliedAir : FilteredAir;
            inout item indoorAir : IndoorAir;

            first receiveSupplyAir;
            then diluteContaminants;
            then stabilizeTemperatureHumidity;
            then updateRoomAir;
            then done;

            action receiveSupplyAir;
            action diluteContaminants;
            action stabilizeTemperatureHumidity;
            action updateRoomAir;
        }
    }

    part def UserInterface {
        port sampleInput : SamplePort;
        port alertInput : AlertPort;

        attribute displayedCO2 : ConcentrationCO2;
        attribute displayedVOC : ConcentrationVOC;
        attribute displayedPM25 : ParticleConcentration;
        attribute displayedQuality : AirQualityLevel;

        action displayStatus {
            in item sample : SensorSample;
            in item alert : MaintenanceAlert;

            first updateNumericReadings;
            then updateQualityIndicator;
            then showMaintenanceAlert;
            then done;

            action updateNumericReadings;
            action updateQualityIndicator;
            action showMaintenanceAlert;
        }
    }

    part def IndoorAirQualitySystem {
        port outdoorAirPort : AirIntakePort;
        port roomAirPort : RoomAirPort;
        port cleanAirPort : SupplyAirPort;
        port exhaustPort : ExhaustAirPort;
        port alertPort : AlertPort;

        part room : RoomZone;
        part sensors : MultiSensorModule;
        part controller : AirQualityController;
        part ventilation : VentilationUnit;
        part filtration : FiltrationModule;
        part interface : UserInterface;

        attribute primaryFunction : String = "Continuously monitor indoor air contaminants and automatically control ventilation and filtration to maintain healthy indoor air quality.";
        attribute designCO2Threshold : ConcentrationCO2 = 900.0;
        attribute designVOCThreshold : ConcentrationVOC = 300.0;
        attribute designPM25Threshold : ParticleConcentration = 12.0;
        attribute nominalAirflow : AirflowRate = 180.0;
        attribute maximumElectricalPower : ElectricPower = 650.0;

        connect outdoorAirPort to ventilation.outdoorAirIn;
        connect roomAirPort to room.roomAirInterface;
        connect room.roomAirInterface to sensors.roomAirPort;
        connect sensors.samplePort to controller.sampleInput;
        connect sensors.samplePort to interface.sampleInput;
        connect controller.commandOutput to ventilation.commandIn;
        connect ventilation.supplyAirOut to filtration.airIn;
        connect filtration.airOut to room.supplyAirIn;
        connect filtration.airOut to cleanAirPort;
        connect room.exhaustAirInterface to ventilation.exhaustAirOut;
        connect ventilation.exhaustAirOut to exhaustPort;
        connect controller.alertOutput to interface.alertInput;
        connect controller.alertOutput to alertPort;
    }

    requirement def MaintainHealthyAirQuality {
        subject system : IndoorAirQualitySystem;

        requirement co2Requirement {
            doc /* The system shall maintain occupied-zone carbon dioxide concentration at or below 900 ppm during normal occupied operation. */
            require constraint { system.room.currentAir.co2 <= 900.0 }
        }

        requirement pm25Requirement {
            doc /* The system shall maintain PM2.5 concentration at or below 12 ug/m3 during normal operation when outdoor air PM2.5 is not greater than 35 ug/m3. */
            require constraint { system.room.currentAir.pm25 <= 12.0 }
        }

        requirement vocRequirement {
            doc /* The system shall maintain total volatile organic compound concentration at or below 300 ppb during normal occupied operation. */
            require constraint { system.room.currentAir.voc <= 300.0 }
        }

        requirement responseRequirement {
            doc /* The system shall enter purge mode within 60 seconds when indoor air quality is classified as unhealthy or critical. */
            require constraint { system.controller.currentMode == OperatingMode::purge }
        }

        requirement monitoringRequirement {
            doc /* The system shall sample temperature, humidity, CO2, VOC, and PM2.5 at least once every 10 seconds. */
            require constraint { system.sensors.measurementPeriod <= 10.0 }
        }

        requirement powerRequirement {
            doc /* The system shall consume no more than 650 W while operating at maximum commanded airflow. */
            require constraint { system.maximumElectricalPower <= 650.0 }
        }

        requirement maintenanceRequirement {
            doc /* The system shall provide a maintenance alert when filter life remaining reaches 10 percent or less. */
            require constraint { system.filtration.filterLifeRemaining >= 0.0 }
        }
    }

    satisfy MaintainHealthyAirQuality by IndoorAirQualitySystem;

    analysis def AirQualityAssessment {
        in item sample : SensorSample;
        out attribute quality : AirQualityLevel;

        objective {
            doc /* Determine the overall indoor air quality level from CO2, VOC, and PM2.5 contaminant measurements using the most severe contaminant category. */
        }
    }

    action def HighLevelOperation {
        inout part system : IndoorAirQualitySystem;

        first monitorIndoorAir;
        then assessContaminants;
        then selectOperatingMode;
        then exchangeAndFilterAir;
        then updateRoomCondition;
        then reportStatus;
        then done;

        action monitorIndoorAir {
            perform system.sensors.senseIndoorAir;
        }

        action assessContaminants {
            perform system.controller.classifyAirQuality;
        }

        action selectOperatingMode {
            perform system.controller.computeControlCommand;
        }

        action exchangeAndFilterAir {
            perform system.ventilation.exchangeAir;
            perform system.filtration.filterAir;
        }

        action updateRoomCondition {
            perform system.room.mixSuppliedAir;
        }

        action reportStatus {
            perform system.interface.displayStatus;
        }
    }

    part indoorAirQualitySystem : IndoorAirQualitySystem {
        attribute primaryFunction = "Maintain a safe and comfortable indoor environment by sensing air quality, evaluating contaminant levels, and automatically applying ventilation and filtration.";
    }
}