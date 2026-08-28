package RainGaugeSystem {
    private import ISQ::*;
    private import SI::*;
    private import ScalarValues::*;

    item def LiquidWater;
    item def TipSignal;
    item def MeasurementData {
        attribute depth : LengthValue;
        attribute rate : SpeedValue;
        attribute totalVolume : VolumeValue;
        attribute timestamp : TimeValue;
    }

    part def CollectorFunnel {
        attribute collectionArea : AreaValue = 100.0 [cm^2];
        out port waterOut : LiquidWater;
    }

    part def TippingBucket {
        attribute calibratedVolume : VolumeValue = 5.0 [mL];
        attribute leftVolume : VolumeValue = 0.0 [mL];
        attribute rightVolume : VolumeValue = 0.0 [mL];
        in port waterIn : LiquidWater;
        out port tipSignalOut : TipSignal;

        exhibit state bucketStateMachine {
            entry; then 'FillingLeft';
            state 'FillingLeft';
            then 'TippingLeft';
            state 'TippingLeft';
            then 'FillingRight';
            state 'FillingRight';
            then 'TippingRight';
            state 'TippingRight';
            then 'FillingLeft';
        }
    }

    calc def CalculateRainfall {
        in tipCount : Integer;
        in volumePerTip : VolumeValue;
        in area : AreaValue;
        in elapsed : TimeValue;
        return computedVolume : VolumeValue = tipCount * volumePerTip;
        return computedDepth : LengthValue = computedVolume / area;
        return computedRate : SpeedValue = computedDepth / elapsed;
    }

    part def MeasurementProcessor {
        in port tipSignalIn : TipSignal;
        out port dataOut : MeasurementData;

        attribute tipCount : Integer = 0;
        attribute volumePerTip : VolumeValue = 5.0 [mL];
        attribute collectionArea : AreaValue = 100.0 [cm^2];
        attribute startTime : TimeValue = 0.0 [s];
        attribute currentTime : TimeValue = 0.0 [s];
        attribute totalVolume : VolumeValue;
        attribute rainfallDepth : LengthValue;
        attribute rainfallRate : SpeedValue;

        calc rainfallCalc : CalculateRainfall {
            in tipCount = tipCount;
            in volumePerTip = volumePerTip;
            in area = collectionArea;
            in elapsed = currentTime - startTime;
            return computedVolume = totalVolume;
            return computedDepth = rainfallDepth;
            return computedRate = rainfallRate;
        }

        exhibit state processorState {
            entry; then 'Idle';
            state 'Idle';
            then 'Processing';
            state 'Processing';
            then 'Idle';
        }
    }

    part def DataRecorder {
        in port dataIn : MeasurementData;
        attribute logInterval : TimeValue = 60.0 [s];
        attribute recordedDepth : LengthValue;
        attribute recordedRate : SpeedValue;
        attribute recordedVolume : VolumeValue;
        attribute recordedTimestamp : TimeValue;

        exhibit state recorderBehavior {
            entry; then 'Idle';
            state 'Idle';
            then 'Logging';
            state 'Logging';
            then 'Idle';
        }
    }

    part def RainGauge {
        part funnel : CollectorFunnel;
        part bucket : TippingBucket;
        part processor : MeasurementProcessor;
        part recorder : DataRecorder;

        connect funnel.waterOut to bucket.waterIn;
        connect bucket.tipSignalOut to processor.tipSignalIn;
        connect processor.dataOut to recorder.dataIn;

        satisfy rainGaugeSpec;
    }

    requirement def RainGaugeRequirements {
        attribute measuredAccuracy : Real;
        attribute measuredMaxRate : SpeedValue;
        attribute measuredResolution : LengthValue;

        attribute requiredAccuracy : Real = 0.02;
        attribute requiredMaxRate : SpeedValue = 300.0 [mm/h];
        attribute requiredResolution : LengthValue = 0.5 [mm];

        require constraint { measuredAccuracy <= requiredAccuracy }
        require constraint { measuredMaxRate >= requiredMaxRate }
        require constraint { measuredResolution <= requiredResolution }
    }

    requirement rainGaugeSpec : RainGaugeRequirements;
}
