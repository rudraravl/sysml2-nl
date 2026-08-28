package StudFinderModel {

    import ScalarValues::*;
    import ISQ::*;
    import ISQSpace::*;
    import ISQTime::*;

    // ---- Value types with units ----

    value type Voltage :> Real { unit 'V'; }
    value type ChargeLevel :> Real { unit 'percent'; }
    value type Capacitance :> Real { unit 'pF'; }
    value type DensityReading :> Real { unit 'pF'; }
    value type Distance :> LengthValue;
    value type Frequency :> Real { unit 'Hz'; }
    value type WallThickness :> LengthValue;
    value type Accuracy :> LengthValue;
    value type Threshold :> Real;

    attribute maxWallThickness : WallThickness = 38 [mm];
    attribute requiredAccuracy : Accuracy = 13 [mm];

    // ---- Item definitions ----

    item def RawSensorData {
        attribute reading : DensityReading;
        attribute timestamp : TimeValue;
    }

    item def ProcessedReading {
        attribute filteredValue : DensityReading;
        attribute baseline : DensityReading;
        attribute delta : DensityReading;
        attribute studDetected : Boolean;
        attribute studEdge : Boolean;
        attribute studCenter : Boolean;
    }

    item def AlertSignal {
        attribute ledLevel : Integer;  // 0..5
        attribute beepActive : Boolean;
        attribute beepFrequency : Frequency;
    }

    item def PowerStatus {
        attribute charge : ChargeLevel;
        attribute lowBattery : Boolean;
    }

    // ---- Port definitions ----

    port def PowerPort {
        out voltage : Voltage;
        out status : PowerStatus;
    }

    port def SensorDataPort {
        out data : RawSensorData;
    }

    port def ProcessedDataPort {
        out reading : ProcessedReading;
    }

    port def AlertPort {
        out signal : AlertSignal;
    }

    // ---- Battery pack ----

    part def BatteryPack {
        attribute nominalVoltage : Voltage = 9 [V];
        attribute maxCharge : ChargeLevel = 100 [percent];
        attribute currentCharge : ChargeLevel = 100 [percent];

        port powerOut : PowerPort;

        exhibit state def BatteryStates {
            entry; then Full;

            state Full {
                entry { currentCharge = 100 [percent]; }
            }

            state Good {
                entry { currentCharge >= 50 [percent]; }
            }

            state Low {
                entry { currentCharge >= 15 [percent] and currentCharge < 50 [percent]; }
            }

            state Critical {
                entry { currentCharge >= 5 [percent] and currentCharge < 15 [percent]; }
            }

            state Depleted {
                entry { currentCharge < 5 [percent]; }
            }

            transition from Full to Good
                when currentCharge < 100 [percent];

            transition from Good to Low
                when currentCharge < 50 [percent];

            transition from Low to Critical
                when currentCharge < 15 [percent];

            transition from Critical to Depleted
                when currentCharge < 5 [percent];
        }

        action def discharge {
            in amount : ChargeLevel;
            // Decrease charge over time
            currentCharge = currentCharge - amount;
        }

        action def getPowerStatus : PowerStatus {
            return PowerStatus {
                charge = currentCharge,
                lowBattery = (currentCharge < 15 [percent])
            };
        }
    }

    // ---- Capacitive sensor ----

    part def CapacitiveSensor {
        attribute samplingRate : Frequency = 100 [Hz];
        attribute currentReading : DensityReading;

        port dataOut : SensorDataPort;
        port powerIn : PowerPort;

        exhibit state def SensorStates {
            entry; then Idle;

            state Idle;
            state Active;

            transition from Idle to Active
                when powerIn.voltage > 0 [V];

            transition from Active to Idle
                when powerIn.voltage == 0 [V];
        }

        action def measureWallDensity : RawSensorData {
            // Simulate measuring capacitance change due to material density
            local raw : DensityReading;
            raw = currentReading;
            return RawSensorData {
                reading = raw,
                timestamp = 0 [s]
            };
        }

        action def continuousSampling {
            while (SensorStates::Active.isActive) {
                dataOut.data = measureWallDensity();
            }
        }
    }

    // ---- Signal processor ----

    part def SignalProcessor {
        attribute filterWindow : Integer = 5;
        attribute detectionThreshold : Threshold = 1.5;
        attribute edgeThreshold : Threshold = 1.0;
        attribute centerThreshold : Threshold = 2.5;
        attribute baselineReading : DensityReading = 0 [pF];
        attribute isCalibrated : Boolean = false;

        port dataIn : SensorDataPort;
        port dataOut : ProcessedDataPort;
        port powerIn : PowerPort;

        action def calibrate {
            in raw : RawSensorData;
            // Establish baseline from empty wall section
            baselineReading = raw.reading;
            isCalibrated = true;
        }

        action def filterReading {
            in raw : RawSensorData;
            return filtered : DensityReading;
            // Simple moving average filter
            filtered = raw.reading;
        }

        action def processReading {
            in raw : RawSensorData;
            return processed : ProcessedReading;

            local filteredVal : DensityReading;
            local deltaVal : DensityReading;
            local detected : Boolean = false;
            local edge : Boolean = false;
            local center : Boolean = false;

            filteredVal = filterReading(raw);
            deltaVal = filteredVal - baselineReading;

            if (deltaVal >= centerThreshold) {
                detected = true;
                center = true;
            } else if (deltaVal >= detectionThreshold) {
                detected = true;
                edge = true;
            } else if (deltaVal >= edgeThreshold) {
                edge = true;
            }

            return ProcessedReading {
                filteredValue = filteredVal,
                baseline = baselineReading,
                delta = deltaVal,
                studDetected = detected,
                studEdge = edge,
                studCenter = center
            };
        }

        action def continuousProcessing {
            while (isCalibrated) {
                local raw : RawSensorData = dataIn.data;
                dataOut.reading = processReading(raw);
            }
        }
    }

    // ---- Visual indicator ----

    part def VisualIndicator {
        attribute numLEDs : Integer = 5;
        attribute ledStates : Boolean[5] = [false, false, false, false, false];

        port alertIn : AlertPort;
        port powerIn : PowerPort;

        action def updateLEDs {
            in level : Integer;
            // Light up LEDs based on proximity level 0..5
            for i in 1..numLEDs {
                ledStates[i] = (i <= level);
            }
        }

        action def monitorAlerts {
            while (true) {
                updateLEDs(alertIn.signal.ledLevel);
            }
        }
    }

    // ---- Audio indicator ----

    part def AudioIndicator {
        attribute buzzerFrequency : Frequency = 4000 [Hz];
        attribute isBeeping : Boolean = false;

        port alertIn : AlertPort;
        port powerIn : PowerPort;

        action def emitBeep {
            in active : Boolean;
            in freq : Frequency;
            isBeeping = active;
            buzzerFrequency = freq;
        }

        action def monitorAlerts {
            while (true) {
                emitBeep(alertIn.signal.beepActive, alertIn.signal.beepFrequency);
            }
        }
    }

    // ---- Alert controller ----

    part def AlertController {
        port readingIn : ProcessedDataPort;
        port alertOut : AlertPort;

        action def generateAlert {
            in reading : ProcessedReading;
            return signal : AlertSignal;

            local level : Integer = 0;
            local beep : Boolean = false;
            local freq : Frequency = 4000 [Hz];

            if (reading.studCenter) {
                level = 5;
                beep = true;
                freq = 4400 [Hz];
            } else if (reading.studDetected) {
                level = 3;
                beep = true;
                freq = 3500 [Hz];
            } else if (reading.studEdge) {
                level = 1;
                beep = false;
            }

            return AlertSignal {
                ledLevel = level,
                beepActive = beep,
                beepFrequency = freq
            };
        }

        action def continuousAlert {
            while (true) {
                alertOut.signal = generateAlert(readingIn.reading);
            }
        }
    }

    // ---- User interface (power button) ----

    part def PowerButton {
        attribute isPressed : Boolean = false;
        attribute powerOn : Boolean = false;

        action def togglePower {
            if (isPressed) {
                powerOn = !powerOn;
            }
        }
    }

    // ---- Stud finder device ----

    part def StudFinder {
        attribute deviceName : String = "StudFinderPro";
        attribute maxDetectionDepth : WallThickness = maxWallThickness;
        attribute locationAccuracy : Accuracy = requiredAccuracy;

        part battery : BatteryPack;
        part sensor : CapacitiveSensor;
        part processor : SignalProcessor;
        part alertController : AlertController;
        part visualIndicator : VisualIndicator;
        part audioIndicator : AudioIndicator;
        part powerButton : PowerButton;

        // Connections
        connection battery.powerOut to sensor.powerIn;
        connection battery.powerOut to processor.powerIn;
        connection battery.powerOut to alertController.powerIn;
        connection battery.powerOut to visualIndicator.powerIn;
        connection battery.powerOut to audioIndicator.powerIn;

        connection sensor.dataOut to processor.dataIn;
        connection processor.dataOut to alertController.readingIn;
        connection alertController.alertOut to visualIndicator.alertIn;
        connection alertController.alertOut to audioIndicator.alertIn;

        exhibit state def DeviceStates {
            entry; then Off;

            state Off {
                entry {
                    // All systems powered down
                }
            }

            state Calibration {
                entry {
                    // User holds against empty wall section
                    processor.isCalibrated = false;
                }
                do {
                    // Collect baseline readings
                    processor.calibrate(sensor.dataOut.data);
                }
            }

            state Scanning {
                entry {
                    // Ready to scan wall surface
                }
                do {
                    processor.continuousProcessing();
                    alertController.continuousAlert();
                }
            }

            state StudDetected {
                entry {
                    // Activate visual and audio alerts
                    visualIndicator.monitorAlerts();
                    audioIndicator.monitorAlerts();
                }
            }

            state LowBatteryShutdown {
                entry {
                    // Graceful shutdown on low battery
                }
            }

            transition from Off to Calibration
                when powerButton.powerOn;

            transition from Calibration to Scanning
                when processor.isCalibrated;

            transition from Scanning to StudDetected
                when alertController.readingIn.reading.studDetected;

            transition from StudDetected to Scanning
                when !alertController.readingIn.reading.studDetected;

            transition from Scanning to Off
                when !powerButton.powerOn;

            transition from StudDetected to Off
                when !powerButton.powerOn;

            transition from Calibration to Off
                when !powerButton.powerOn;

            transition from Scanning to LowBatteryShutdown
                when battery.powerOut.status.lowBattery;

            transition from StudDetected to LowBatteryShutdown
                when battery.powerOut.status.lowBattery;

            transition from LowBatteryShutdown to Off
                when battery.powerOut.status.charge < 5 [percent];
        }
    }

    // ---- Requirements ----

    requirement def DetectionDepthRequirement {
        attribute requiredDepth : WallThickness = maxWallThickness;
        subject studFinder : StudFinder;
        requirement {
            studFinder.maxDetectionDepth >= requiredDepth
        }
    }

    requirement def LocationAccuracyRequirement {
        attribute requiredAcc : Accuracy = requiredAccuracy;
        subject studFinder : StudFinder;
        requirement {
            studFinder.locationAccuracy <= requiredAcc
        }
    }

    requirement def PowerRequirement {
        subject battery : BatteryPack;
        requirement {
            battery.nominalVoltage == 9 [V]
        }
    }

    requirement def CalibrationRequirement {
        subject processor : SignalProcessor;
        requirement {
            // Device must enter calibration mode on power-up before scanning
            StudFinder::DeviceStates::Calibration.isEntered before
            StudFinder::DeviceStates::Scanning.isEntered
        }
    }

    requirement def DualAlertRequirement {
        subject studFinder : StudFinder;
        requirement {
            // Must alert via both visual and audio indicators when stud detected
            studFinder.visualIndicator.ledStates.contains(true) and
            studFinder.audioIndicator.isBeeping
            when studFinder.alertController.readingIn.reading.studDetected
        }
    }

    requirement def BatteryStateTrackingRequirement {
        subject battery : BatteryPack;
        requirement {
            // Battery must track charge from full to depleted
            BatteryPack::BatteryStates::Full.isActive or
            BatteryPack::BatteryStates::Good.isActive or
            BatteryPack::BatteryStates::Low.isActive or
            BatteryPack::BatteryStates::Critical.isActive or
            BatteryPack::BatteryStates::Depleted.isActive
        }
    }

    requirement def ContinuousScanningRequirement {
        subject sensor : CapacitiveSensor;
        requirement {
            // Sensor must continuously measure density during scanning
            CapacitiveSensor::SensorStates::Active.isActive
            when StudFinder::DeviceStates::Scanning.isActive
        }
    }

    // ---- Top-level requirement ----

    requirement StudFinderRequirements {
        subject studFinder : StudFinder;

        satisfy DetectionDepthRequirement {
            subject studFinder = studFinder;
        }

        satisfy LocationAccuracyRequirement {
            subject studFinder = studFinder;
        }

        satisfy PowerRequirement {
            subject battery = studFinder.battery;
        }

        satisfy CalibrationRequirement {
            subject processor = studFinder.processor;
        }

        satisfy DualAlertRequirement {
            subject studFinder = studFinder;
        }

        satisfy BatteryStateTrackingRequirement {
            subject battery = studFinder.battery;
        }

        satisfy ContinuousScanningRequirement {
            subject sensor = studFinder.sensor;
        }
    }

    // ---- Instantiation ----

    part def StudFinderSystem {
        part device : StudFinder {
            satisfy StudFinderRequirements {
                subject studFinder = device;
            }
        }
    }

}
