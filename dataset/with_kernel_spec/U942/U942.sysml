package DigitalWaterMeterModel {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;

    item def Water;
    item def MeasurementRecord {
        attribute cumulativeVolume :> ISQ::volume;
        attribute instantaneousFlowRate :> ISQ::volumeFlowRate;
        attribute timestamp :> Time::DateTime;
    }

    port def WaterFlowPort {
        attribute pressure :> ISQ::pressure;
        attribute flowRate :> ISQ::volumeFlowRate;
    }
    port def FlowRateOutPort {
        out flowRate :> ISQ::volumeFlowRate;
    }
    port def FlowRateInPort {
        in flowRate :> ISQ::volumeFlowRate;
    }
    port def VolumeOutPort {
        out totalVolume :> ISQ::volume;
    }
    port def VolumeInPort {
        in totalVolume :> ISQ::volume;
    }
    port def RecordOutPort {
        out record : MeasurementRecord;
    }
    port def RecordInPort {
        in record : MeasurementRecord;
    }
    port def StatusOutPort {
        out faultDetected : Boolean;
    }
    port def StatusInPort {
        in faultDetected : Boolean;
    }

    action def MeasureFlowRate {
        in item water : Water;
        out flowRate :> ISQ::volumeFlowRate;
    }
    action def IntegrateVolume {
        in flowRate :> ISQ::volumeFlowRate;
        in timestamp :> Time::DateTime;
        out totalVolume :> ISQ::volume;
        out record : MeasurementRecord;
    }
    action def DisplayReadings {
        in flowRate :> ISQ::volumeFlowRate;
        in totalVolume :> ISQ::volume;
    }
    action def LogMeasurement {
        in record : MeasurementRecord;
        out stored : Boolean;
    }

    state def WaterMeterStates;

    part def FlowSensor {
        attribute measuredFlowRate :> ISQ::volumeFlowRate;
        attribute faultDetected : Boolean = false;
        port waterIn : WaterFlowPort;
        port waterOut : WaterFlowPort;
        port flowRateOut : FlowRateOutPort;
        port statusOut : StatusOutPort;
        perform action measureFlowRate : MeasureFlowRate;
    }
    part def VolumeIntegrator {
        attribute accumulatedVolume :> ISQ::volume;
        port flowRateIn : FlowRateInPort;
        port volumeOut : VolumeOutPort;
        port recordOut : RecordOutPort;
        perform action integrateVolume : IntegrateVolume;
    }
    part def DisplayModule {
        attribute displayedFlowRate :> ISQ::volumeFlowRate;
        attribute displayedVolume :> ISQ::volume;
        port flowRateIn : FlowRateInPort;
        port volumeIn : VolumeInPort;
        perform action displayReadings : DisplayReadings;
    }
    part def DataLogger {
        attribute logInterval :> ISQ::time;
        attribute logCount : Integer;
        ref item storedRecords : MeasurementRecord [0..*];
        port recordIn : RecordInPort;
        perform action logMeasurement : LogMeasurement;
    }
    part def WaterMeter {
        attribute accuracyPercent : Real;
        attribute minOperatingPressure :> ISQ::pressure;
        attribute maxOperatingPressure :> ISQ::pressure;
        attribute minFlowRate :> ISQ::volumeFlowRate;
        attribute maxFlowRate :> ISQ::volumeFlowRate;
        port waterInletPort : WaterFlowPort;
        port waterOutletPort : WaterFlowPort;
        part flowSensor : FlowSensor;
        part volumeIntegrator : VolumeIntegrator;
        part displayModule : DisplayModule;
        part dataLogger : DataLogger;
        perform action measureFlowRate : MeasureFlowRate;
        perform action integrateVolume : IntegrateVolume;
        perform action displayReadings : DisplayReadings;
        perform action logMeasurement : LogMeasurement;
        exhibit state meterStates : WaterMeterStates;
    }

    requirement def MeasurementAccuracyRequirement {
        doc /* The water meter shall measure cumulative volume within ±2% of the true value. */
        subject meter : WaterMeter;
        attribute actualVolume :> ISQ::volume;
        attribute measuredVolume :> ISQ::volume;
        attribute maxRelativeError : Real = 0.02;
        assert constraint {
            (measuredVolume - actualVolume) <= maxRelativeError * actualVolume
        }
        assert constraint {
            (actualVolume - measuredVolume) <= maxRelativeError * actualVolume
        }
    }
    requirement def PressureRangeRequirement {
        doc /* The water meter shall operate reliably across residential water pressures from 20 kPa to 800 kPa. */
        subject meter : WaterMeter;
        attribute minPressure :> ISQ::pressure;
        attribute maxPressure :> ISQ::pressure;
        assert constraint {
            meter.minOperatingPressure >= minPressure
        }
        assert constraint {
            meter.maxOperatingPressure <= maxPressure
        }
    }
    requirement def FlowRateRangeRequirement {
        doc /* The water meter shall measure flow rates typical of residential use. */
        subject meter : WaterMeter;
        attribute minFlowRate :> ISQ::volumeFlowRate;
        attribute maxFlowRate :> ISQ::volumeFlowRate;
        assert constraint {
            meter.minFlowRate <= minFlowRate
        }
        assert constraint {
            meter.maxFlowRate >= maxFlowRate
        }
    }

    part residentialWaterMeter : WaterMeter {
        attribute :>> accuracyPercent = 2.0;
        attribute :>> minOperatingPressure = 20000[SI::Pa];
        attribute :>> maxOperatingPressure = 800000[SI::Pa];
        part :>> flowSensor : FlowSensor {
            attribute :>> faultDetected = false;
        }
        part :>> volumeIntegrator : VolumeIntegrator {
            attribute :>> accumulatedVolume = 0[SI::m3];
        }
        part :>> displayModule : DisplayModule;
        part :>> dataLogger : DataLogger {
            attribute :>> logInterval = 60[SI::s];
            attribute :>> logCount = 0;
        }
        connect waterInletPort to flowSensor.waterIn;
        connect flowSensor.waterOut to waterOutletPort;
        connect flowSensor.flowRateOut to volumeIntegrator.flowRateIn;
        connect flowSensor.flowRateOut to displayModule.flowRateIn;
        connect volumeIntegrator.volumeOut to displayModule.volumeIn;
        connect volumeIntegrator.recordOut to dataLogger.recordIn;
        state meterStates : WaterMeterStates {
            entry; then idle;
            state idle;
            accept when flowSensor.measuredFlowRate > 0
                then active;
            accept when flowSensor.faultDetected
                then error;
            state active {
                entry measureFlowRate;
                do integrateVolume;
                do displayReadings;
                do logMeasurement;
            }
            accept when flowSensor.measuredFlowRate <= 0
                then idle;
            accept when flowSensor.faultDetected
                then error;
            state error;
            accept when flowSensor.faultDetected == false
                then idle;
        }
    }

    requirement measurementAccuracyReq : MeasurementAccuracyRequirement {
        subject meter :> residentialWaterMeter;
    }
    requirement pressureRangeReq : PressureRangeRequirement {
        subject meter :> residentialWaterMeter;
        attribute :>> minPressure = 20000[SI::Pa];
        attribute :>> maxPressure = 800000[SI::Pa];
    }
    requirement flowRateRangeReq : FlowRateRangeRequirement {
        subject meter :> residentialWaterMeter;
    }

    verification def WaterMeterAccuracyTest {
        subject testMeter : WaterMeter;
        objective accuracyObjective {
            verify measurementAccuracyReq;
        }
        action collectData {
            in part testMeter : WaterMeter = WaterMeterAccuracyTest::testMeter;
            out volumeMeasured :> ISQ::volume;
        }
        action processData {
            in volumeMeasured :> ISQ::volume = collectData.volumeMeasured;
            out volumeProcessed :> ISQ::volume;
        }
        action evaluateData {
            in volumeProcessed :> ISQ::volume = processData.volumeProcessed;
            out verdict : VerdictKind;
        }
        return verdict : VerdictKind = evaluateData.verdict;
    }

    verification waterMeterAccuracyTest : WaterMeterAccuracyTest {
        subject testMeter :> residentialWaterMeter;
    }
}
