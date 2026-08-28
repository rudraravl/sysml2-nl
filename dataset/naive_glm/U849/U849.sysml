package RainGaugeSystem {
    import ScalarValues::*;

    // =====================================================
    //  Units
    // =====================================================
    unit mm;
    unit cm2;
    unit mL;
    unit s;
    unit min;
    unit mm_per_hr;

    // =====================================================
    //  Value Types with Units
    // =====================================================
    value type Depth :> Real {
        unit : mm;
    }
    value type Area :> Real {
        unit : cm2;
    }
    value type Volume :> Real {
        unit : mL;
    }
    value type DurationSec :> Real {
        unit : s;
    }
    value type IntervalMin :> Real {
        unit : min;
    }
    value type RainRate :> Real {
        unit : mm_per_hr;
    }
    value type Percent :> Real;

    // =====================================================
    //  Item Definitions
    // =====================================================
    item def RainWater {
        doc "Captured rainfall water channeled through the funnel.";
        attribute volume : Volume;
        attribute temperature : Real;
    }

    item def TipSignal {
        doc "Electronic pulse generated when the tipping bucket completes a tip.";
        attribute tipIndex : Integer;
        attribute timestamp : DurationSec;
        attribute cumulativeCount : Integer;
    }

    item def MeasurementRecord {
        doc "Time-stamped rainfall measurement transmitted from processor to recorder.";
        attribute timestamp : DurationSec;
        attribute totalDepth : Depth;
        attribute totalVolume : Volume;
        attribute instantaneousRate : RainRate;
        attribute intervalTipCount : Integer;
    }

    // =====================================================
    //  Port Definitions
    // =====================================================
    port def WaterInPort {
        in item water : RainWater;
    }
    port def WaterOutPort {
        out item water : RainWater;
    }
    port def TipSignalOutPort {
        out item tip : TipSignal;
    }
    port def TipSignalInPort {
        in item tip : TipSignal;
    }
    port def MeasurementOutPort {
        out item record : MeasurementRecord;
    }
    port def MeasurementInPort {
        in item record : MeasurementRecord;
    }

    // =====================================================
    //  Component Part Definitions
    // =====================================================
    part def CollectorFunnel {
        doc "Captures falling rain over a calibrated area and channels it to the tipping bucket.";
        attribute collectionArea : Area = 100 [cm2];
        port waterOut : WaterOutPort;

        action def ChannelWater {
            in rainfall : RainWater;
            out channeled : RainWater;
            do {
                channeled = rainfall;
            }
        }

        state machine FunnelStates {
            state Idle;
            state Channeling;
            initial transition to Idle;
            transition from Idle to Channeling
                accept RainWater
                do {
                    send waterOut.water to waterOut;
                };
            transition from Channeling to Idle;
        }
    }

    part def TippingBucketMechanism {
        doc "Calibrated two-sided bucket that tips when a fixed volume of water has accumulated.";
        attribute calibratedVolumePerTip : Volume = 5.0 [mL];
        attribute currentVolume : Volume = 0 [mL];
        attribute activeSide : Integer = 0;
        attribute tipCount : Integer = 0;
        attribute lastTipTimestamp : DurationSec = 0 [s];

        port waterIn : WaterInPort;
        port tipSignalOut : TipSignalOutPort;

        action def TipBucket {
            out signal : TipSignal;
            do {
                tipCount = tipCount + 1;
                lastTipTimestamp = lastTipTimestamp + 1;
                signal = TipSignal(
                    tipIndex = tipCount,
                    timestamp = lastTipTimestamp,
                    cumulativeCount = tipCount
                );
            }
        }

        state machine BucketStateMachine {
            state Empty;
            state FillingLeft;
            state TippingLeftToRight;
            state FillingRight;
            state TippingRightToLeft;

            initial transition to Empty;

            transition from Empty to FillingLeft
                accept RainWater via waterIn.water
                do {
                    activeSide = 0;
                    currentVolume = currentVolume + waterIn.water.volume;
                };

            transition from FillingLeft to TippingLeftToRight
                when currentVolume >= calibratedVolumePerTip
                do {
                    tipCount = tipCount + 1;
                    lastTipTimestamp = lastTipTimestamp + 1;
                    send TipSignal(
                        tipIndex = tipCount,
                        timestamp = lastTipTimestamp,
                        cumulativeCount = tipCount
                    ) to tipSignalOut.tip;
                    currentVolume = 0 [mL];
                    activeSide = 1;
                };

            transition from TippingLeftToRight to FillingRight
                accept RainWater via waterIn.water
                do {
                    currentVolume = currentVolume + waterIn.water.volume;
                };

            transition from FillingRight to TippingRightToLeft
                when currentVolume >= calibratedVolumePerTip
                do {
                    tipCount = tipCount + 1;
                    lastTipTimestamp = lastTipTimestamp + 1;
                    send TipSignal(
                        tipIndex = tipCount,
                        timestamp = lastTipTimestamp,
                        cumulativeCount = tipCount
                    ) to tipSignalOut.tip;
                    currentVolume = 0 [mL];
                    activeSide = 0;
                };

            transition from TippingRightToLeft to FillingLeft
                accept RainWater via waterIn.water
                do {
                    currentVolume = currentVolume + waterIn.water.volume;
                };
        }
    }

    part def MeasurementProcessor {
        doc "Counts tip signals and computes accumulated volume, precipitation depth, and rainfall rate.";
        attribute funnelArea : Area = 100 [cm2];
        attribute volumePerTip : Volume = 5.0 [mL];
        attribute depthPerTip : Depth = 0.5 [mm];
        attribute tipCount : Integer = 0;
        attribute totalVolume : Volume = 0 [mL];
        attribute totalDepth : Depth = 0 [mm];
        attribute currentRate : RainRate = 0 [mm_per_hr];
        attribute lastTipTimestamp : DurationSec = 0 [s];
        attribute previousTipTimestamp : DurationSec = 0 [s];

        port tipSignalIn : TipSignalInPort;
        port measurementOut : MeasurementOutPort;

        action def ProcessTip {
            in signal : TipSignal;
            out record : MeasurementRecord;
            do {
                tipCount = signal.cumulativeCount;
                totalVolume = tipCount * volumePerTip;
                totalDepth = tipCount * depthPerTip;
                previousTipTimestamp = lastTipTimestamp;
                lastTipTimestamp = signal.timestamp;
                if (lastTipTimestamp > previousTipTimestamp) {
                    currentRate = depthPerTip * 3600 / (lastTipTimestamp - previousTipTimestamp);
                }
                record = MeasurementRecord(
                    timestamp = signal.timestamp,
                    totalDepth = totalDepth,
                    totalVolume = totalVolume,
                    instantaneousRate = currentRate,
                    intervalTipCount = tipCount
                );
            }
        }

        state machine ProcessorStateMachine {
            state Idle;
            state Receiving;
            state Calculating;
            state Emitting;

            initial transition to Idle;

            transition from Idle to Receiving
                accept TipSignal via tipSignalIn.tip;

            transition from Receiving to Calculating
                do {
                    tipCount = tipSignalIn.tip.cumulativeCount;
                    totalVolume = tipCount * volumePerTip;
                    totalDepth = tipCount * depthPerTip;
                    previousTipTimestamp = lastTipTimestamp;
                    lastTipTimestamp = tipSignalIn.tip.timestamp;
                    if (lastTipTimestamp > previousTipTimestamp) {
                        currentRate = depthPerTip * 3600 / (lastTipTimestamp - previousTipTimestamp);
                    }
                };

            transition from Calculating to Emitting
                do {
                    send MeasurementRecord(
                        timestamp = lastTipTimestamp,
                        totalDepth = totalDepth,
                        totalVolume = totalVolume,
                        instantaneousRate = currentRate,
                        intervalTipCount = tipCount
                    ) to measurementOut.record;
                };

            transition from Emitting to Idle;
        }
    }

    part def DataRecorder {
        doc "Logs time-stamped rainfall measurement records at a fixed interval to build a historical record.";
        attribute loggingInterval : IntervalMin = 1.0 [min];
        attribute loggingIntervalSec : DurationSec = 60 [s];
        attribute records : MeasurementRecord[*];
        attribute latestRecord : MeasurementRecord;
        attribute lastLogTime : DurationSec = 0 [s];

        port measurementIn : MeasurementInPort;

        action def LogRecord {
            in record : MeasurementRecord;
            do {
                records = records.append(record);
                lastLogTime = record.timestamp;
            }
        }

        state machine RecorderStateMachine {
            state Waiting;
            state Receiving;
            state Logging;

            initial transition to Waiting;

            transition from Waiting to Receiving
                accept MeasurementRecord via measurementIn.record
                do {
                    latestRecord = measurementIn.record;
                };

            transition from Receiving to Waiting;

            transition from Waiting to Logging
                after 60 [s]
                do {
                    if (latestRecord.timestamp > 0 [s]) {
                        records = records.append(latestRecord);
                        lastLogTime = latestRecord.timestamp;
                    }
                };

            transition from Logging to Waiting;
        }
    }

    // =====================================================
    //  Top-Level System
    // =====================================================
    part def RainGaugeSystem {
        doc "Automated electronic tipping-bucket rain gauge system for accurate precipitation measurement.";

        attribute nominalAccuracy : Percent = 2.0;
        attribute maxRainfallRate : RainRate = 300 [mm_per_hr];
        attribute resolution : Depth = 0.5 [mm];
        attribute loggingInterval : IntervalMin = 1.0 [min];

        part collectorFunnel : CollectorFunnel {
            attribute collectionArea = 100 [cm2];
        }

        part tippingBucket : TippingBucketMechanism {
            attribute calibratedVolumePerTip = 5.0 [mL];
        }

        part measurementProcessor : MeasurementProcessor {
            attribute funnelArea = 100 [cm2];
            attribute volumePerTip = 5.0 [mL];
            attribute depthPerTip = 0.5 [mm];
        }

        part dataRecorder : DataRecorder {
            attribute loggingInterval = 1.0 [min];
        }

        connection def WaterConduit {
            end source : WaterOutPort;
            end target : WaterInPort;
        }
        connection def TipSignalConduit {
            end source : TipSignalOutPort;
            end target : TipSignalInPort;
        }
        connection def DataConduit {
            end source : MeasurementOutPort;
            end target : MeasurementInPort;
        }

        connection funnelToBucket : WaterConduit
            connect collectorFunnel.waterOut to tippingBucket.waterIn;

        connection bucketToProcessor : TipSignalConduit
            connect tippingBucket.tipSignalOut to measurementProcessor.tipSignalIn;

        connection processorToRecorder : DataConduit
            connect measurementProcessor.measurementOut to dataRecorder.measurementIn;
    }

    // =====================================================
    //  Requirements
    // =====================================================
    requirement def AccuracyRequirement {
        doc "The rain gauge shall measure precipitation depth with an accuracy of ±2% of the true value.";
        attribute requiredAccuracy : Percent;
        constraint { requiredAccuracy >= -2.0 and requiredAccuracy <= 2.0 }
    }

    requirement def MaxRainfallRateRequirement {
        doc "The rain gauge shall measure rainfall rates up to 300 mm/hr.";
        attribute maxRate : RainRate;
        constraint { maxRate >= 300 [mm_per_hr] }
    }

    requirement def ResolutionRequirement {
        doc "The rain gauge shall provide a measurement resolution of 0.5 mm of precipitation depth.";
        attribute requiredResolution : Depth;
        constraint { requiredResolution == 0.5 [mm] }
    }

    requirement def LoggingIntervalRequirement {
        doc "The data recorder shall log measurements every 60 seconds.";
        attribute requiredInterval : IntervalMin;
        constraint { requiredInterval == 1.0 [min] }
    }

    requirement def CollectorAreaRequirement {
        doc "The collector funnel shall have a collection surface area of 100 cm2.";
        attribute requiredArea : Area;
        constraint { requiredArea == 100 [cm2] }
    }

    requirement def CalibratedVolumeRequirement {
        doc "The tipping bucket shall tip when 5.0 mL of water has been collected.";
        attribute requiredVolume : Volume;
        constraint { requiredVolume == 5.0 [mL] }
    }

    requirement RainGaugeAccuracyReq : AccuracyRequirement {
        attribute requiredAccuracy = 2.0;
        subject rainGauge : RainGaugeSystem;
    }

    requirement MaxRateReq : MaxRainfallRateRequirement {
        attribute maxRate = 300 [mm_per_hr];
        subject rainGauge : RainGaugeSystem;
    }

    requirement ResolutionReq : ResolutionRequirement {
        attribute requiredResolution = 0.5 [mm];
        subject rainGauge : RainGaugeSystem;
    }

    requirement LoggingIntervalReq : LoggingIntervalRequirement {
        attribute requiredInterval = 1.0 [min];
        subject recorder : DataRecorder;
    }

    requirement CollectorAreaReq : CollectorAreaRequirement {
        attribute requiredArea = 100 [cm2];
        subject funnel : CollectorFunnel;
    }

    requirement CalibratedVolumeReq : CalibratedVolumeRequirement {
        attribute requiredVolume = 5.0 [mL];
        subject bucket : TippingBucketMechanism;
    }

    // =====================================================
    //  Verification Cases
    // =====================================================
    verification def AccuracyVerification {
        doc "Verify that the rain gauge meets the ±2% accuracy requirement.";
        objective { verify RainGaugeAccuracyReq; }
    }

    verification def MaxRateVerification {
        doc "Verify that the rain gauge measures rainfall rates up to 300 mm/hr.";
        objective { verify MaxRateReq; }
    }

    verification def ResolutionVerification {
        doc "Verify that the rain gauge provides a resolution of 0.5 mm.";
        objective { verify ResolutionReq; }
    }

    verification def LoggingIntervalVerification {
        doc "Verify that the data recorder logs every 60 seconds.";
        objective { verify LoggingIntervalReq; }
    }

    verification def CollectorAreaVerification {
        doc "Verify that the collector funnel area is 100 cm2.";
        objective { verify CollectorAreaReq; }
    }

    verification def CalibratedVolumeVerification {
        doc "Verify that the tipping bucket tips at 5.0 mL.";
        objective { verify CalibratedVolumeReq; }
    }
}
