package CGM {

    package Units {
        unit def mgPerdL;
        unit def mgPerdLperMin;
        unit def minute;
        unit def hour;
        unit def day;
        unit def meter;
        unit def percent;
        unit def count;
    }

    package ValueTypes {
        value type GlucoseConcentration :> Real { unit mgPerdL; }
        value type RateOfChange :> Real { unit mgPerdLperMin; }
        value type DurationValue :> Real { unit minute; }
        value type DistanceValue :> Real { unit meter; }
        value type BatteryLevel :> Real { unit percent; }
        value type ReadingCount :> Real { unit count; }
        value type PredictionHorizon :> Real { unit minute; }
    }

    package Items {
        item def RawSensorSignal {
            attribute rawValue : GlucoseConcentration;
            attribute timestamp : TimeInstantValue;
        }
        item def GlucoseReading {
            attribute glucoseValue : GlucoseConcentration;
            attribute timestamp : TimeInstantValue;
            attribute trend : TrendArrow;
        }
        item def TrendArrow {
            enum literal Rising;
            enum literal Falling;
            enum literal Steady;
            enum literal RisingRapidly;
            enum literal FallingRapidly;
        }
        item def PredictedGlucose {
            attribute predictedValue : GlucoseConcentration;
            attribute predictionTime : TimeInstantValue;
            attribute horizon : PredictionHorizon;
        }
        item def AlertMessage {
            attribute alertType : AlertType;
            attribute glucoseValue : GlucoseConcentration;
            attribute timestamp : TimeInstantValue;
        }
        item def AlertType {
            enum literal Low;
            enum literal High;
            enum literal CriticalLow;
            enum literal CriticalHigh;
        }
        item def CalibrationValue {
            attribute bloodGlucoseValue : GlucoseConcentration;
            attribute timestamp : TimeInstantValue;
        }
        item def DisplayData {
            attribute currentReading : GlucoseReading;
            attribute predicted : PredictedGlucose;
            attribute trend : TrendArrow;
        }
        value type TimeInstantValue :> Real;
    }

    package Ports {
        port def RawSignalOut {
            out signal : Items::RawSensorSignal;
        }
        port def RawSignalIn {
            in signal : Items::RawSensorSignal;
        }
        port def WirelessDataOut {
            out reading : Items::GlucoseReading;
            out prediction : Items::PredictedGlucose;
        }
        port def WirelessDataIn {
            in reading : Items::GlucoseReading;
            in prediction : Items::PredictedGlucose;
        }
        port def AlertOut {
            out alert : Items::AlertMessage;
        }
        port def AlertIn {
            in alert : Items::AlertMessage;
        }
        port def CalibrationIn {
            in calibration : Items::CalibrationValue;
        }
        port def DisplayOut {
            out displayData : Items::DisplayData;
        }
    }

    package Behaviors {

        action def MeasureGlucose {
            in interstitialFluid : GlucoseConcentration;
            out rawSignal : Items::RawSensorSignal;
        }

        action def FilterSignal {
            in rawSignal : Items::RawSensorSignal;
            out filteredReading : Items::GlucoseReading;
        }

        action def CalculateTrend {
            in currentReading : Items::GlucoseReading;
            in previousReadings : Items::GlucoseReading[0..*];
            out rate : RateOfChange;
            out trend : Items::TrendArrow;
        }

        action def PredictGlucose {
            in currentReading : Items::GlucoseReading;
            in rate : RateOfChange;
            out prediction : Items::PredictedGlucose;
        }

        action def EvaluateAlerts {
            in reading : Items::GlucoseReading;
            out alert : Items::AlertMessage[0..*];
        }

        action def CalibrateSensor {
            in calibration : Items::CalibrationValue;
            in currentReading : Items::GlucoseReading;
            out calibrationFactor : Real;
        }

        action def RenderDisplay {
            in displayData : Items::DisplayData;
            in alert : Items::AlertMessage[0..*];
        }

        state def SensorStates {
            entry; then Active;
            state Active {
                entry; then Measuring;
                state Measuring {
                    entry { send RawSensorSignal; }
                    do { perform MeasureGlucose; }
                    transition from Measuring to Measuring
                        when (elapsed >= 5 [minute]);
                }
                transition from Active to Expired
                    when (operationalAge >= 10 [day]);
            }
            state Expired {
                entry { emit "Sensor replacement required"; }
            }
        }

        state def TransmitterStates {
            entry; then Powered;
            state Powered {
                entry; then Receiving;
                state Receiving {
                    transition from Receiving to Processing
                        when (rawSignal received);
                }
                state Processing {
                    do { perform FilterSignal; }
                    transition from Processing to Transmitting
                        when (filteredReading ready);
                }
                state Transmitting {
                    entry { send GlucoseReading; }
                    transition from Transmitting to Receiving
                        when (transmission complete);
                }
                transition from Powered to LowBattery
                    when (batteryLevel < 10 [percent]);
            }
            state LowBattery {
                entry { emit "Transmitter battery low"; }
            }
        }

        state def ReceiverStates {
            entry; then Listening;
            state Listening {
                transition from Listening to Receiving
                    when (wirelessData received);
            }
            state Receiving {
                do { accept GlucoseReading; }
                transition from Receiving to Displaying
                    when (reading received);
            }
            state Displaying {
                do { perform RenderDisplay; }
                transition from Displaying to Listening
                    when (display updated);
            }
            transition from ReceiverStates to AlertActive
                when (alert received);
            state AlertActive {
                entry { emit audio or vibration alert; }
                transition from AlertActive to Listening
                    when (alert acknowledged);
            }
        }

        state def AlertManagerStates {
            entry; then Monitoring;
            state Monitoring {
                do { perform EvaluateAlerts; }
                transition from Monitoring to AlertTriggered
                    when (alert generated);
            }
            state AlertTriggered {
                entry { send AlertMessage; }
                transition from AlertTriggered to Monitoring
                    when (alert delivered);
            }
        }

        state def CalibrationManagerStates {
            entry; then AwaitingCalibration;
            state AwaitingCalibration {
                transition from AwaitingCalibration to Calibrating
                    when (calibrationValue received);
                transition from AwaitingCalibration to CalibrationOverdue
                    when (elapsed >= 12 [hour]);
            }
            state Calibrating {
                do { perform CalibrateSensor; }
                transition from Calibrating to AwaitingCalibration
                    when (calibration complete);
            }
            state CalibrationOverdue {
                entry { emit "Calibration required"; }
                transition from CalibrationOverdue to Calibrating
                    when (calibrationValue received);
            }
        }
    }

    package Parts {

        part def Sensor {
            attribute operationalLifetime : DurationValue = 10 [day];
            attribute measurementInterval : DurationValue = 5 [minute];
            attribute operationalAge : DurationValue;
            port glucoseOut : Ports::RawSignalOut;
            part filament : Filament;
            part def Filament {
                attribute insertionDepth : DistanceValue = 0.005 [meter];
            }
            state machine :>> Behaviors::SensorStates;
        }

        part def Transmitter {
            attribute wirelessRange : DistanceValue = 6 [meter];
            attribute batteryLevel : BatteryLevel = 100 [percent];
            port rawIn : Ports::RawSignalIn;
            port dataOut : Ports::WirelessDataOut;
            part battery : Battery;
            part def Battery {
                attribute capacity : BatteryLevel = 100 [percent];
            }
            state machine :>> Behaviors::TransmitterStates;
        }

        part def DataAnalysisProcessor {
            port rawIn : Ports::RawSignalIn;
            port dataOut : Ports::WirelessDataOut;
            attribute predictionHorizon : PredictionHorizon = 30 [minute];
            part filter : SignalFilter;
            part trendCalculator : TrendCalculator;
            part predictor : GlucosePredictor;
            part def SignalFilter {
                attribute noiseThreshold : Real;
            }
            part def TrendCalculator {
                attribute windowSize : ReadingCount = 12 [count];
            }
            part def GlucosePredictor {
                attribute horizon : PredictionHorizon = 30 [minute];
            }
            perform action :>> Behaviors::FilterSignal;
            perform action :>> Behaviors::CalculateTrend;
            perform action :>> Behaviors::PredictGlucose;
        }

        part def AlertManager {
            attribute lowThreshold : GlucoseConcentration = 70 [mgPerdL];
            attribute highThreshold : GlucoseConcentration = 180 [mgPerdL];
            attribute criticalLowThreshold : GlucoseConcentration = 54 [mgPerdL];
            attribute criticalHighThreshold : GlucoseConcentration = 250 [mgPerdL];
            port alertOut : Ports::AlertOut;
            state machine :>> Behaviors::AlertManagerStates;
            perform action :>> Behaviors::EvaluateAlerts;
        }

        part def CalibrationManager {
            attribute calibrationInterval : DurationValue = 12 [hour];
            port calibrationIn : Ports::CalibrationIn;
            state machine :>> Behaviors::CalibrationManagerStates;
            perform action :>> Behaviors::CalibrateSensor;
        }

        part def Receiver {
            attribute storageCapacity : DurationValue = 90 [day];
            port dataIn : Ports::WirelessDataIn;
            port alertIn : Ports::AlertIn;
            port calibrationIn : Ports::CalibrationIn;
            port displayOut : Ports::DisplayOut;
            part display : Display;
            part audioAlert : AudioAlert;
            part vibrationAlert : VibrationAlert;
            part storage : DataStorage;
            part def Display {
                attribute resolution : Real;
            }
            part def AudioAlert {
                attribute volume : Real;
            }
            part def VibrationAlert {
                attribute intensity : Real;
            }
            part def DataStorage {
                attribute capacity : DurationValue = 90 [day];
            }
            state machine :>> Behaviors::ReceiverStates;
            perform action :>> Behaviors::RenderDisplay;
        }

        part def CGMSystem {
            part sensor : Sensor;
            part transmitter : Transmitter;
            part receiver : Receiver;
            part processor : DataAnalysisProcessor;
            part alertManager : AlertManager;
            part calibrationManager : CalibrationManager;

            connection sensorToProcessor : RawSignalLink
                connect sensor.glucoseOut to processor.rawIn;
            connection processorToTransmitter : ProcessedDataLink
                connect processor.dataOut to transmitter.dataOut;
            connection transmitterToReceiver : WirelessLink
                connect transmitter.dataOut to receiver.dataIn;
            connection alertManagerToReceiver : AlertLink
                connect alertManager.alertOut to receiver.alertIn;
            connection receiverToCalibration : CalibrationLink
                connect receiver.calibrationIn to calibrationManager.calibrationIn;

            connection def RawSignalLink {
                end source : Ports::RawSignalOut;
                end target : Ports::RawSignalIn;
            }
            connection def ProcessedDataLink {
                end source : Ports::WirelessDataOut;
                end target : Ports::WirelessDataIn;
            }
            connection def WirelessLink {
                end source : Ports::WirelessDataOut;
                end target : Ports::WirelessDataIn;
            }
            connection def AlertLink {
                end source : Ports::AlertOut;
                end target : Ports::AlertIn;
            }
            connection def CalibrationLink {
                end source : Ports::CalibrationIn;
                end target : Ports::CalibrationIn;
            }
        }
    }

    package Requirements {

        requirement def CGMRequirement {
            subject cgm : Parts::CGMSystem;
        }

        requirement ContinuousMonitoring :> CGMRequirement {
            subject sensor : Parts::Sensor;
            requirement constraint {
                sensor.measurementInterval == 5 [minute]
            }
        }

        requirement SensorLifetime :> CGMRequirement {
            subject sensor : Parts::Sensor;
            requirement constraint {
                sensor.operationalLifetime >= 10 [day]
            }
        }

        requirement WirelessRange :> CGMRequirement {
            subject transmitter : Parts::Transmitter;
            requirement constraint {
                transmitter.wirelessRange >= 6 [meter]
            }
        }

        requirement DisplayContent :> CGMRequirement {
            subject receiver : Parts::Receiver;
            requirement constraint {
                receiver.display shows currentReading
                and receiver.display shows timestamp
                and receiver.display shows trend
            }
        }

        requirement HistoricalStorage :> CGMRequirement {
            subject receiver : Parts::Receiver;
            requirement constraint {
                receiver.storageCapacity >= 90 [day]
            }
        }

        requirement PredictionCapability :> CGMRequirement {
            subject processor : Parts::DataAnalysisProcessor;
            requirement constraint {
                processor.predictionHorizon >= 30 [minute]
            }
        }

        requirement LowAlertThreshold :> CGMRequirement {
            subject alertManager : Parts::AlertManager;
            requirement constraint {
                alertManager.lowThreshold == 70 [mgPerdL]
            }
        }

        requirement HighAlertThreshold :> CGMRequirement {
            subject alertManager : Parts::AlertManager;
            requirement constraint {
                alertManager.highThreshold == 180 [mgPerdL]
            }
        }

        requirement CriticalAlerts :> CGMRequirement {
            subject alertManager : Parts::AlertManager;
            requirement constraint {
                alertManager.criticalLowThreshold == 54 [mgPerdL]
                and alertManager.criticalHighThreshold == 250 [mgPerdL]
            }
        }

        requirement AlertDelivery :> CGMRequirement {
            subject receiver : Parts::Receiver;
            requirement constraint {
                receiver.audioAlert delivers audio
                or receiver.vibrationAlert delivers vibration
            }
        }

        requirement CalibrationInterval :> CGMRequirement {
            subject calibrationManager : Parts::CalibrationManager;
            requirement constraint {
                calibrationManager.calibrationInterval <= 12 [hour]
            }
        }

        requirement CalibrationReference :> CGMRequirement {
            subject calibrationManager : Parts::CalibrationManager;
            requirement constraint {
                calibrationManager accepts CalibrationValue
                from fingerstick blood glucose test
            }
        }

        requirement SignalFiltering :> CGMRequirement {
            subject processor : Parts::DataAnalysisProcessor;
            requirement constraint {
                processor.filter removes signal noise
            }
        }

        requirement TrendCalculation :> CGMRequirement {
            subject processor : Parts::DataAnalysisProcessor;
            requirement constraint {
                processor.trendCalculator calculates rate
                and processor.trendCalculator calculates direction
            }
        }
    }
}
