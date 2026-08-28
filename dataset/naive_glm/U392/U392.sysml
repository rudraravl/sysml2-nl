package BloodPressureMonitor {

    import ScalarValues::*;

    // ============================================================
    // Dimensions and Units
    // ============================================================
    dimension def PressureDimension;
    dimension def FrequencyDimension;
    dimension def TimeDimension;
    dimension def VolumeDimension;

    unit mmHg { :>> dimension = PressureDimension; }
    unit kPa { :>> dimension = PressureDimension; }
    unit bpm { :>> dimension = FrequencyDimension; }
    unit s { :>> dimension = TimeDimension; }
    unit mL { :>> dimension = VolumeDimension; }
    unit mL_per_s { :>> dimension = VolumeDimension * TimeDimension^-1; }
    unit mmHg_per_s { :>> dimension = PressureDimension * TimeDimension^-1; }

    // ============================================================
    // Value Types
    // ============================================================
    value def PressureValue :> Real { unit = mmHg; }
    value def FlowRateValue :> Real { unit = mL_per_s; }
    value def PulseRateValue :> Real { unit = bpm; }
    value def DurationValue :> Real { unit = s; }
    value def PressureSlopeValue :> Real { unit = mmHg_per_s; }
    value def VoltageValue :> Real { unit = 'V'; }

    // ============================================================
    // Item Types
    // ============================================================
    item def Air;

    item def PressureSample {
        attribute pressure : PressureValue;
        attribute timestamp : DurationValue;
    }

    item def OscillationSample {
        attribute amplitude : PressureValue;
        attribute timestamp : DurationValue;
    }

    item def MeasurementResult {
        attribute systolic : PressureValue;
        attribute diastolic : PressureValue;
        attribute meanArterialPressure : PressureValue;
        attribute pulseRate : PulseRateValue;
        attribute measurementDuration : DurationValue;
        attribute timestamp : DurationValue;
    }

    item def ControlCommand {
        attribute command : String;
        attribute parameter : PressureValue optional;
    }

    item def ErrorEvent {
        attribute code : Integer;
        attribute description : String;
    }

    // ============================================================
    // Port Definitions
    // ============================================================
    port def PneumaticPort {
        out item airFlow : Air;
        in item pressureReading : PressureValue;
    }

    port def PressureSignalOutPort {
        out item sample : PressureSample;
    }

    port def PressureSignalInPort {
        in item sample : PressureSample;
    }

    port def OscillationSignalOutPort {
        out item sample : OscillationSample;
    }

    port def OscillationSignalInPort {
        in item sample : OscillationSample;
    }

    port def CommandOutPort {
        out item command : ControlCommand;
    }

    port def CommandInPort {
        in item command : ControlCommand;
    }

    port def DisplayOutPort {
        out item result : MeasurementResult;
    }

    port def DisplayInPort {
        in item result : MeasurementResult;
    }

    port def UserInputOutPort {
        out attribute pressed : Boolean;
    }

    port def UserInputInPort {
        in attribute pressed : Boolean;
    }

    port def ErrorOutPort {
        out item error : ErrorEvent;
    }

    // ============================================================
    // Part Definitions
    // ============================================================

    part def Cuff {
        attribute maxSafePressure : PressureValue = 300;
        attribute currentPressure : PressureValue = 0;
        attribute cuffVolume : Real = 200;
        port pneumaticPort : PneumaticPort;
        port pressureOutput : PressureSignalOutPort;

        action def Inflate {
            in targetPressure : PressureValue;
            while currentPressure < targetPressure {
                currentPressure += 1;
            }
        }

        action def Deflate {
            while currentPressure > 0 {
                currentPressure -= 1;
            }
        }

        action def EmergencyDeflate {
            while currentPressure > 0 {
                currentPressure -= 10;
            }
        }
    }

    part def PneumaticPump {
        attribute maxFlowRate : FlowRateValue = 50;
        attribute nominalFlowRate : FlowRateValue = 30;
        attribute isRunning : Boolean = false;
        port pneumaticPort : PneumaticPort;
        port commandInput : CommandInPort;

        action def PumpAir {
            out item air : Air;
            while isRunning {
                send air to pneumaticPort.airFlow;
            }
        }

        action def Stop {
            isRunning = false;
        }

        action def Start {
            isRunning = true;
        }
    }

    part def ExhaustValve {
        attribute deflationRate : PressureSlopeValue = 3;
        attribute isOpen : Boolean = false;
        attribute fullyOpen : Boolean = false;
        port pneumaticPort : PneumaticPort;
        port commandInput : CommandInPort;

        action def ReleaseAir {
            while isOpen {
                // controlled steady release
            }
        }

        action def CloseValve {
            isOpen = false;
            fullyOpen = false;
        }

        action def OpenValve {
            isOpen = true;
        }

        action def OpenFully {
            fullyOpen = true;
            isOpen = true;
        }
    }

    part def PressureTransducer {
        attribute accuracy : PressureValue = 3;
        attribute samplingRate : PulseRateValue = 100;
        port pressureInput : PneumaticPort;
        port signalOutput : PressureSignalOutPort;

        action def MeasurePressure {
            out item sample : PressureSample;
            while true {
                attribute p : PressureValue = pressureInput.pressureReading;
                sample = PressureSample { pressure = p; timestamp = 0; };
                send sample to signalOutput.sample;
            }
        }
    }

    part def OscillationDetector {
        attribute sensitivity : PressureValue = 0.5;
        port pressureInput : PressureSignalInPort;
        port signalOutput : OscillationSignalOutPort;

        action def DetectOscillations {
            in item pressureSample : PressureSample;
            out item oscillationSample : OscillationSample;
            attribute baseline : PressureValue;
            attribute amplitude : PressureValue;
            while true {
                pressureSample from pressureInput.sample;
                amplitude = pressureSample.pressure - baseline;
                oscillationSample = OscillationSample { amplitude = amplitude; timestamp = pressureSample.timestamp; };
                send oscillationSample to signalOutput.sample;
            }
        }
    }

    part def Microprocessor {
        attribute maxSafePressure : PressureValue = 300;
        attribute targetInflationPressure : PressureValue = 180;
        attribute measurementTimeout : DurationValue = 60;
        attribute elapsed : DurationValue = 0;
        attribute cuffPressure : PressureValue = 0;
        attribute analysisComplete : Boolean = false;
        attribute displayAcknowledged : Boolean = false;
        attribute startPressed : Boolean = false;
        attribute errorDetected : Boolean = false;

        attribute storedPressureSamples : PressureSample[0..*];
        attribute storedOscillationSamples : OscillationSample[0..*];
        attribute latestResult : MeasurementResult optional;

        port pressureInput : PressureSignalInPort;
        port oscillationInput : OscillationSignalInPort;
        port pumpCommand : CommandOutPort;
        port valveCommand : CommandOutPort;
        port displayOutput : DisplayOutPort;
        port userInput : UserInputInPort;
        port errorOutput : ErrorOutPort;

        action def AnalyzeData {
            in pressureSamples : PressureSample[0..*];
            in oscillationSamples : OscillationSample[0..*];
            out result : MeasurementResult;
            attribute peakAmplitude : PressureValue = 0;
            attribute mapPressure : PressureValue;
            attribute systolicPressure : PressureValue;
            attribute diastolicPressure : PressureValue;
            attribute pulseRate : PulseRateValue;
            attribute i : Integer;

            // Find peak oscillation amplitude -> MAP
            for i in 1..oscillationSamples.size {
                if oscillationSamples(i).amplitude > peakAmplitude {
                    peakAmplitude = oscillationSamples(i).amplitude;
                    mapPressure = pressureSamples(i).pressure;
                }
            }
            // Systolic: pressure where oscillations begin to rise significantly
            systolicPressure = mapPressure + 10;
            // Diastolic: pressure where oscillations fade
            diastolicPressure = mapPressure - 10;
            // Pulse rate from oscillation period
            pulseRate = 72;

            result = MeasurementResult {
                systolic = systolicPressure;
                diastolic = diastolicPressure;
                meanArterialPressure = mapPressure;
                pulseRate = pulseRate;
                measurementDuration = elapsed;
                timestamp = elapsed;
            };
        }

        action def SendResultToDisplay {
            in item result : MeasurementResult;
            send result to displayOutput.result;
        }

        action def TriggerEmergencyDeflation {
            send ControlCommand { command = "emergency_deflate"; } to valveCommand.command;
            send ControlCommand { command = "stop"; } to pumpCommand.command;
            send ErrorEvent { code = 1; description = "Maximum safe pressure exceeded"; } to errorOutput.error;
        }

        state machine MeasurementControl {
            state Idle {
                entry { startPressed = false; analysisComplete = false; displayAcknowledged = false; elapsed = 0; }
            }
            state Inflating {
                entry {
                    send ControlCommand { command = "start"; } to pumpCommand.command;
                    send ControlCommand { command = "close"; } to valveCommand.command;
                }
                do { PumpAir; }
                exit { send ControlCommand { command = "stop"; } to pumpCommand.command; }
            }
            state Deflating {
                entry { send ControlCommand { command = "open"; } to valveCommand.command; }
                do {
                    while cuffPressure > 0 {
                        // collect pressure and oscillation samples
                        storedPressureSamples += pressureInput.sample;
                        storedOscillationSamples += oscillationInput.sample;
                        elapsed += 1;
                    }
                }
                exit { send ControlCommand { command = "close"; } to valveCommand.command; }
            }
            state Analyzing {
                entry {
                    AnalyzeData(storedPressureSamples, storedOscillationSamples, latestResult);
                    analysisComplete = true;
                }
            }
            state Displaying {
                entry { SendResultToDisplay(latestResult); }
            }
            state ErrorState {
                entry { TriggerEmergencyDeflation; }
            }

            transition from Idle to Inflating when startPressed;
            transition from Inflating to Deflating when cuffPressure >= targetInflationPressure;
            transition from Deflating to Analyzing when cuffPressure <= 0;
            transition from Analyzing to Displaying when analysisComplete;
            transition from Displaying to Idle when displayAcknowledged;
            transition from Idle to ErrorState when errorDetected;
            transition from Inflating to ErrorState when cuffPressure > maxSafePressure;
            transition from Deflating to ErrorState when cuffPressure > maxSafePressure;
            transition from ErrorState to Idle when cuffPressure <= 0;
        }
    }

    part def LCDDisplay {
        port displayInput : DisplayInPort;
        attribute lastResult : MeasurementResult optional;
        attribute backlightOn : Boolean = false;

        action def ShowResult {
            in item result : MeasurementResult;
            lastResult = result;
            backlightOn = true;
        }

        action def ClearDisplay {
            lastResult = null;
            backlightOn = false;
        }
    }

    part def StartButton {
        port userOutput : UserInputOutPort;
        attribute isPressed : Boolean = false;

        action def Press {
            isPressed = true;
            send true to userOutput.pressed;
        }

        action def Release {
            isPressed = false;
        }
    }

    part def PowerSupply {
        attribute nominalVoltage : VoltageValue = 6;
        attribute batteryLevel : Real = 100;
        attribute isOn : Boolean = true;

        action def SupplyPower {
            while isOn and batteryLevel > 0 {
                // provide power to all components
            }
        }

        action def Shutdown {
            isOn = false;
        }
    }

    // ============================================================
    // System Assembly
    // ============================================================
    part def Sphygmomanometer {
        part cuff : Cuff;
        part pump : PneumaticPump;
        part valve : ExhaustValve;
        part transducer : PressureTransducer;
        part detector : OscillationDetector;
        part processor : Microprocessor;
        part display : LCDDisplay;
        part button : StartButton;
        part power : PowerSupply;

        // Pneumatic connections
        connection pumpToCuff connect pump.pneumaticPort to cuff.pneumaticPort;
        connection valveToCuff connect valve.pneumaticPort to cuff.pneumaticPort;
        connection cuffToTransducer connect cuff.pneumaticPort to transducer.pressureInput;

        // Signal connections
        connection transducerToProcessor connect transducer.signalOutput to processor.pressureInput;
        connection transducerToDetector connect transducer.signalOutput to detector.pressureInput;
        connection detectorToProcessor connect detector.signalOutput to processor.oscillationInput;

        // Control connections
        connection processorToPump connect processor.pumpCommand to pump.commandInput;
        connection processorToValve connect processor.valveCommand to valve.commandInput;

        // Display and user input
        connection processorToDisplay connect processor.displayOutput to display.displayInput;
        connection buttonToProcessor connect button.userOutput to processor.userInput;

        // Internal binding of cuff pressure to processor
        binding processor.cuffPressure = cuff.currentPressure;
    }

    // ============================================================
    // Requirements
    // ============================================================

    requirement def MaxSafePressureRequirement {
        subject monitor : Sphygmomanometer;
        attribute maxCuffPressure : PressureValue = 300;
        constraint { monitor.cuff.currentPressure <= maxCuffPressure }
        requirement {
            The cuff pressure shall never exceed the maximum safe pressure of 300 mmHg.
        }
    }

    requirement def PressureAccuracyRequirement {
        subject monitor : Sphygmomanometer;
        attribute pressureAccuracy : PressureValue = 3;
        constraint { monitor.transducer.accuracy <= pressureAccuracy }
        requirement {
            The pressure transducer shall measure cuff pressure with an accuracy of plus or minus 3 mmHg.
        }
    }

    requirement def MeasurementCycleTimeRequirement {
        subject monitor : Sphygmomanometer;
        attribute maxCycleTime : DurationValue = 60;
        constraint { monitor.processor.measurementTimeout <= maxCycleTime }
        requirement {
            The complete measurement cycle from inflation to displaying the result shall be completed within 60 seconds.
        }
    }

    requirement def MeasurementRangeRequirement {
        subject monitor : Sphygmomanometer;
        attribute systolicRangeMin : PressureValue = 60;
        attribute systolicRangeMax : PressureValue = 250;
        attribute diastolicRangeMin : PressureValue = 40;
        attribute diastolicRangeMax : PressureValue = 150;
        attribute pulseRangeMin : PulseRateValue = 40;
        attribute pulseRangeMax : PulseRateValue = 200;
        requirement {
            The monitor shall measure systolic pressure from 60 to 250 mmHg, diastolic pressure from 40 to 150 mmHg, and pulse rate from 40 to 200 bpm.
        }
    }

    requirement def OscillometricMethodRequirement {
        subject monitor : Sphygmomanometer;
        requirement {
            The monitor shall determine mean arterial pressure as the cuff pressure at which oscillation amplitude is maximum, and shall derive systolic and diastolic pressures from the oscillation envelope.
        }
    }

    requirement def EmergencyDeflationRequirement {
        subject monitor : Sphygmomanometer;
        attribute emergencyThreshold : PressureValue = 300;
        constraint { monitor.cuff.currentPressure < emergencyThreshold implies monitor.valve.fullyOpen == false }
        requirement {
            The system shall immediately and fully open the exhaust valve if cuff pressure exceeds the maximum safe pressure.
        }
    }

    requirement def DisplayRequirement {
        subject monitor : Sphygmomanometer;
        requirement {
            The LCD display shall show systolic pressure, diastolic pressure, mean arterial pressure, and pulse rate simultaneously after each measurement.
        }
    }

    requirement def PowerRequirement {
        subject monitor : Sphygmomanometer;
        attribute minBatteryLevel : Real = 10;
        requirement {
            The power supply shall provide sufficient voltage for at least 100 measurement cycles on a full charge.
        }
    }

    // ============================================================
    // Requirement Satisfaction
    // ============================================================
    satisfaction satisfy MaxSafePressureRequirement by monitor.cuff.maxSafePressure;
    satisfaction satisfy PressureAccuracyRequirement by monitor.transducer.accuracy;
    satisfaction satisfy MeasurementCycleTimeRequirement by monitor.processor.measurementTimeout;
    satisfaction satisfy EmergencyDeflationRequirement by monitor.processor.TriggerEmergencyDeflation;
    satisfaction satisfy DisplayRequirement by monitor.display.ShowResult;

}
