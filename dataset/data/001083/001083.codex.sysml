package HookGaugeEvaporimeterModel {

    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    attribute def LengthValue {
        :>> num : Real;
        unit : Unit;
    }

    attribute def AreaValue {
        :>> num : Real;
        unit : Unit;
    }

    attribute def VolumeValue {
        :>> num : Real;
        unit : Unit;
    }

    attribute def TemperatureValue {
        :>> num : Real;
        unit : Unit;
    }

    attribute def EvaporationDepthValue {
        :>> num : Real;
        unit : Unit;
    }

    attribute def TimeValue {
        :>> num : Real;
        unit : Unit;
    }

    attribute def RateValue {
        :>> num : Real;
        unit : Unit;
    }

    item def Water;
    item def RainWater :> Water;
    item def MakeUpWater :> Water;
    item def EvaporatedWater :> Water;
    item def OverflowWater :> Water;

    item def ReadingRecord {
        attribute readingTime : TimeValue;
        attribute hookElevation : LengthValue;
        attribute waterSurfaceElevation : LengthValue;
        attribute panWaterTemperature : TemperatureValue;
    }

    item def EvaporationObservation {
        attribute startReading : LengthValue;
        attribute endReading : LengthValue;
        attribute elapsedTime : TimeValue;
        attribute rainfallCorrection : EvaporationDepthValue;
        attribute makeUpCorrection : EvaporationDepthValue;
        attribute evaporationDepth : EvaporationDepthValue;
        attribute evaporationRate : RateValue;
    }

    port def WaterPort {
        in item waterIn : Water;
        out item waterOut : Water;
    }

    port def VaporPort {
        out item vaporOut : EvaporatedWater;
    }

    port def ReadingPort {
        out item recordOut : ReadingRecord;
    }

    port def ObservationPort {
        out item observationOut : EvaporationObservation;
    }

    port def ControlPort {
        in item commandIn : ControlCommand;
        out item statusOut : SystemStatus;
    }

    item def ControlCommand {
        attribute commandCode : String;
    }

    item def SystemStatus {
        attribute statusCode : String;
        attribute message : String;
    }

    part def EvaporationPan {
        attribute panDiameter : LengthValue = (num = 1.21, unit = m);
        attribute panDepth : LengthValue = (num = 0.255, unit = m);
        attribute waterSurfaceArea : AreaValue = (num = 1.15, unit = m^2);
        attribute nominalWaterDepth : LengthValue = (num = 0.200, unit = m);
        attribute minimumOperationalDepth : LengthValue = (num = 0.150, unit = m);
        attribute maximumOperationalDepth : LengthValue = (num = 0.230, unit = m);
        attribute currentWaterDepth : LengthValue;
        attribute waterTemperature : TemperatureValue;
        port waterPort : WaterPort;
        port vaporPort : VaporPort;

        action exposeWaterSurface {
            in item containedWater : Water;
            out item evaporatedWater : EvaporatedWater;
        }
    }

    part def HookGaugeAssembly {
        attribute hookTipRadius : LengthValue = (num = 0.00025, unit = m);
        attribute verticalTravelRange : LengthValue = (num = 0.250, unit = m);
        attribute scaleResolution : LengthValue = (num = 0.0001, unit = m);
        attribute zeroReferenceElevation : LengthValue = (num = 0.000, unit = m);
        attribute currentHookElevation : LengthValue;
        port readingPort : ReadingPort;

        action lowerHookBelowSurface {
            out item status : SystemStatus;
        }

        action raiseHookToSurfaceContact {
            in attribute targetMeniscusCondition : String;
            out item reading : ReadingRecord;
        }

        action captureReading {
            in attribute waterTemperature : TemperatureValue;
            out item record : ReadingRecord;
        }
    }

    part def StillWell {
        attribute internalDiameter : LengthValue = (num = 0.100, unit = m);
        attribute dampingTimeConstant : TimeValue = (num = 8.0, unit = s);
        attribute screenedInletHeight : LengthValue = (num = 0.020, unit = m);
        port waterPort : WaterPort;

        action dampSurfaceWaves {
            in item panWater : Water;
            out item quietWaterSurface : Water;
        }
    }

    part def ReferenceBench {
        attribute installedLevelTolerance : LengthValue = (num = 0.001, unit = m);
        attribute benchmarkElevation : LengthValue = (num = 0.000, unit = m);

        action supportGauge {
            out item status : SystemStatus;
        }
    }

    part def RainGauge {
        attribute catchArea : AreaValue = (num = 0.020, unit = m^2);
        attribute resolution : EvaporationDepthValue = (num = 0.0002, unit = m);
        attribute accumulatedRainfall : EvaporationDepthValue;
        port observationPort : ObservationPort;

        action measureRainfall {
            out attribute rainfallDepth : EvaporationDepthValue;
        }
    }

    part def MakeUpReservoir {
        attribute capacity : VolumeValue = (num = 0.020, unit = m^3);
        attribute deliveredVolume : VolumeValue;
        port waterPort : WaterPort;

        action addWaterToReferenceDepth {
            in attribute targetDepth : LengthValue;
            in attribute currentDepth : LengthValue;
            out item makeUpWater : MakeUpWater;
            out attribute makeUpDepthEquivalent : EvaporationDepthValue;
        }
    }

    part def OverflowDrain {
        attribute crestElevation : LengthValue = (num = 0.230, unit = m);
        port waterPort : WaterPort;

        action dischargeExcessWater {
            in item excessWater : Water;
            out item overflowWater : OverflowWater;
        }
    }

    part def ObservationController {
        attribute scheduledInterval : TimeValue = (num = 86400.0, unit = s);
        attribute lastReadingElevation : LengthValue;
        attribute currentReadingElevation : LengthValue;
        attribute elapsedTime : TimeValue;
        attribute rainfallCorrection : EvaporationDepthValue;
        attribute makeUpCorrection : EvaporationDepthValue;
        attribute computedEvaporationDepth : EvaporationDepthValue;
        attribute computedEvaporationRate : RateValue;
        port controlPort : ControlPort;
        port readingPort : ReadingPort;
        port observationPort : ObservationPort;

        action startObservationCycle {
            out item status : SystemStatus;
        }

        action computeEvaporation {
            in attribute previousReading : LengthValue;
            in attribute presentReading : LengthValue;
            in attribute rainfallDepth : EvaporationDepthValue;
            in attribute makeUpDepth : EvaporationDepthValue;
            in attribute observationTime : TimeValue;
            out item observation : EvaporationObservation;
        }

        action validateObservation {
            in item observation : EvaporationObservation;
            out item status : SystemStatus;
        }

        state machine observationStateMachine {
            state idle;
            state prepareGauge;
            state stabilizeWaterSurface;
            state takeInitialReading;
            state exposePan;
            state takeFinalReading;
            state applyCorrections;
            state reportEvaporation;
            state fault;

            entry action idle {
                send SystemStatus { statusCode = "IDLE", message = "Awaiting observation command"; } via controlPort.statusOut;
            }

            transition first idle to prepareGauge
                accept ControlCommand
                if commandIn.commandCode == "START_OBSERVATION";

            transition prepareGauge to stabilizeWaterSurface;
            transition stabilizeWaterSurface to takeInitialReading;
            transition takeInitialReading to exposePan;
            transition exposePan to takeFinalReading
                after scheduledInterval;
            transition takeFinalReading to applyCorrections;
            transition applyCorrections to reportEvaporation;
            transition reportEvaporation to idle;
            transition prepareGauge to fault
                if statusOut.statusCode == "FAULT";
            transition takeInitialReading to fault
                if statusOut.statusCode == "READING_INVALID";
            transition takeFinalReading to fault
                if statusOut.statusCode == "READING_INVALID";
            transition fault to idle
                accept ControlCommand
                if commandIn.commandCode == "RESET";
        }
    }

    part def HookGaugeEvaporimeter {
        attribute primaryFunction : String =
            "Measure open-water evaporation by detecting small changes in the water level of a standardized evaporation pan with a precision hook gauge and converting the corrected level change into evaporation depth and rate.";
        attribute operatingWaterDepth : LengthValue = (num = 0.200, unit = m);
        attribute measurementResolution : EvaporationDepthValue = (num = 0.0001, unit = m);
        attribute dailyObservationInterval : TimeValue = (num = 86400.0, unit = s);

        part pan : EvaporationPan;
        part hookGauge : HookGaugeAssembly;
        part stillWell : StillWell;
        part referenceBench : ReferenceBench;
        part rainGauge : RainGauge;
        part makeUpReservoir : MakeUpReservoir;
        part overflowDrain : OverflowDrain;
        part controller : ObservationController;

        port waterSupplyPort : WaterPort;
        port vaporReleasePort : VaporPort;
        port controlPort : ControlPort;
        port observationPort : ObservationPort;

        connect waterSupplyPort to makeUpReservoir.waterPort;
        connect makeUpReservoir.waterPort to pan.waterPort;
        connect pan.waterPort to stillWell.waterPort;
        connect pan.waterPort to overflowDrain.waterPort;
        connect pan.vaporPort to vaporReleasePort;
        connect hookGauge.readingPort to controller.readingPort;
        connect rainGauge.observationPort to controller.observationPort;
        connect controller.controlPort to controlPort;
        connect controller.observationPort to observationPort;

        action performDailyEvaporationMeasurement {
            in item command : ControlCommand;
            out item observation : EvaporationObservation;
            out item finalStatus : SystemStatus;

            first start;
            then action supportGauge : referenceBench.supportGauge;
            then action dampSurface : stillWell.dampSurfaceWaves;
            then action initialContact : hookGauge.raiseHookToSurfaceContact {
                targetMeniscusCondition = "hook tip just pierces reflected surface";
            }
            then action expose : pan.exposeWaterSurface;
            then action rainfall : rainGauge.measureRainfall;
            then action finalContact : hookGauge.raiseHookToSurfaceContact {
                targetMeniscusCondition = "hook tip just pierces reflected surface";
            }
            then action refill : makeUpReservoir.addWaterToReferenceDepth {
                targetDepth = operatingWaterDepth;
            }
            then action calculate : controller.computeEvaporation;
            then action verify : controller.validateObservation;
            then done;
        }
    }

    requirement def PrimaryFunctionRequirement {
        subject evaporimeter : HookGaugeEvaporimeter;
        require constraint {
            evaporimeter.primaryFunction ==
            "Measure open-water evaporation by detecting small changes in the water level of a standardized evaporation pan with a precision hook gauge and converting the corrected level change into evaporation depth and rate."
        }
    }

    requirement def MeasurementResolutionRequirement {
        subject evaporimeter : HookGaugeEvaporimeter;
        require constraint {
            evaporimeter.measurementResolution.num <= 0.0001
        }
    }

    requirement def PanGeometryRequirement {
        subject pan : EvaporationPan;
        require constraint {
            pan.panDiameter.num >= 1.20 and
            pan.panDepth.num >= 0.25 and
            pan.waterSurfaceArea.num > 1.0
        }
    }

    requirement def WaterDepthOperatingRequirement {
        subject pan : EvaporationPan;
        require constraint {
            pan.currentWaterDepth.num >= pan.minimumOperationalDepth.num and
            pan.currentWaterDepth.num <= pan.maximumOperationalDepth.num
        }
    }

    requirement def ObservationCorrectionRequirement {
        subject observation : EvaporationObservation;
        require constraint {
            observation.evaporationDepth.num ==
            observation.startReading.num -
            observation.endReading.num +
            observation.rainfallCorrection.num -
            observation.makeUpCorrection.num
        }
    }

    requirement def EvaporationRateRequirement {
        subject observation : EvaporationObservation;
        require constraint {
            observation.evaporationRate.num ==
            observation.evaporationDepth.num / observation.elapsedTime.num
        }
    }

    requirement def OverflowProtectionRequirement {
        subject drain : OverflowDrain;
        require constraint {
            drain.crestElevation.num <= 0.230
        }
    }

    satisfy PrimaryFunctionRequirement by HookGaugeEvaporimeter;
    satisfy MeasurementResolutionRequirement by HookGaugeEvaporimeter;
    satisfy PanGeometryRequirement by EvaporationPan;
    satisfy WaterDepthOperatingRequirement by EvaporationPan;
    satisfy ObservationCorrectionRequirement by ObservationController;
    satisfy EvaporationRateRequirement by ObservationController;
    satisfy OverflowProtectionRequirement by OverflowDrain;

    part evaporimeterSystem : HookGaugeEvaporimeter {
        attribute :>> operatingWaterDepth = (num = 0.200, unit = m);
        attribute :>> measurementResolution = (num = 0.0001, unit = m);
        attribute :>> dailyObservationInterval = (num = 86400.0, unit = s);
    }
}