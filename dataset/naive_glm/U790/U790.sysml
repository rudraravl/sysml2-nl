package DigitalOdometerSystem {
    import ScalarValues::*;
    import ISQ::*;
    import ISQBase::*;

    // ===== Value Types =====
    attribute def PulseCount :> ScalarValue {
        :>> unit = "pulse";
    }
    attribute def PulsesPerRevolution :> ScalarValue {
        :>> unit = "pulse/rev";
    }
    attribute def WheelDiameter :> LengthValue {
        :>> unit = "m";
    }
    attribute def Distance :> LengthValue {
        :>> unit = "km";
    }
    attribute def Speed :> SpeedValue {
        :>> unit = "km/h";
    }
    attribute def Frequency :> ScalarValue {
        :>> unit = "Hz";
    }
    attribute def Revolutions :> ScalarValue {
        :>> unit = "rev";
    }
    attribute def Time :> TimeValue {
        :>> unit = "s";
    }

    // ===== Item Types =====
    item def PulseStream {
        attribute pulseCount : PulseCount;
        attribute timestamp : Time;
    }
    item def DistanceData {
        attribute totalDistance : Distance;
        attribute tripDistance : Distance;
        attribute currentSpeed : Speed;
    }
    item def StoredOdometerReading {
        attribute totalDistance : Distance;
    }
    item def TripResetCommand;
    item def DisplayCommand {
        attribute totalDistance : Distance;
        attribute tripDistance : Distance;
        attribute currentSpeed : Speed;
    }

    // ===== Port Definitions =====
    port def PulseOutputPort {
        out pulseStream : PulseStream;
    }
    port def PulseInputPort {
        in pulseStream : PulseStream;
    }
    port def DistanceOutputPort {
        out distanceData : DistanceData;
    }
    port def DistanceInputPort {
        in distanceData : DistanceData;
    }
    port def StorageWritePort {
        out storedReading : StoredOdometerReading;
    }
    port def StorageReadPort {
        in storedReading : StoredOdometerReading;
    }
    port def DisplayCommandPort {
        out displayCmd : DisplayCommand;
    }
    port def DisplayInputPort {
        in displayCmd : DisplayCommand;
    }
    port def TripResetPort {
        out resetCmd : TripResetCommand;
    }
    port def TripResetInputPort {
        in resetCmd : TripResetCommand;
    }

    // ===== Requirements =====
    requirement def OdometerRequirements {
        requirement MeasureTotalDistance {
            doc /* The system shall measure and store the total cumulative distance traveled by the vehicle. */
        }
        requirement DisplaySpeed {
            doc /* The system shall display the current speed of the vehicle. */
        }
        requirement TripMeterFunction {
            doc /* The system shall track a resettable trip distance independent of the total odometer. */
        }
        requirement NonVolatileRetention {
            doc /* The system shall retain total mileage in non-volatile storage when powered off. */
        }
        requirement LoadOnStartup {
            doc /* The system shall load the stored total distance upon initialization before measuring new distance. */
        }
        requirement PulseBasedMeasurement {
            doc /* The system shall convert wheel rotation sensor pulses into distance and speed using the known wheel diameter. */
        }
    }

    // ===== Parts =====

    part def WheelRotationSensor {
        attribute pulsesPerRevolution : PulsesPerRevolution = 48[pulse/rev];
        attribute wheelDiameter : WheelDiameter = 0.6[m];
        port pulseOut : PulseOutputPort;

        action def GeneratePulses {
            in revolution : Revolutions;
            out pulses : PulseStream;
        }
    }

    part def DistanceCalculationUnit {
        attribute wheelDiameter : WheelDiameter = 0.6[m];
        attribute pulsesPerRevolution : PulsesPerRevolution = 48[pulse/rev];
        attribute circumference : LengthValue = 3.14159 * wheelDiameter;
        attribute totalDistance : Distance = 0[km];
        attribute tripDistance : Distance = 0[km];
        attribute currentSpeed : Speed = 0[km/h];
        attribute pulseBuffer : PulseCount = 0[pulse];
        attribute lastTimestamp : Time = 0[s];

        port pulseIn : PulseInputPort;
        port distanceOut : DistanceOutputPort;
        port storageWrite : StorageWritePort;
        port storageRead : StorageReadPort;
        port tripResetIn : TripResetInputPort;
        port displayOut : DisplayCommandPort;

        action def ProcessPulses {
            in incomingPulses : PulseStream;
            out computedDistance : DistanceData;
            attribute incrementalDistance : Distance;
            attribute pulseFrequency : Frequency;

            action ComputeIncrementalDistance {
                in pulses : PulseCount;
                out dist : Distance;
            }
            action ComputeSpeed {
                in freq : Frequency;
                out spd : Speed;
            }
            action UpdateTotalDistance {
                in delta : Distance;
                out total : Distance;
            }
            action UpdateTripDistance {
                in delta : Distance;
                out trip : Distance;
            }
        }

        action def LoadStoredData {
            in reading : StoredOdometerReading;
            out loadedTotal : Distance;
        }

        action def SaveData {
            in total : Distance;
            out reading : StoredOdometerReading;
        }

        action def ResetTrip {
            out resetTrip : Distance = 0[km];
        }
    }

    part def DisplayUnit {
        attribute displayedTotalDistance : Distance = 0[km];
        attribute displayedTripDistance : Distance = 0[km];
        attribute displayedSpeed : Speed = 0[km/h];

        port displayIn : DisplayInputPort;

        action def RenderDisplay {
            in cmd : DisplayCommand;
            attribute totalDisplay : Distance;
            attribute tripDisplay : Distance;
            attribute speedDisplay : Speed;
        }
    }

    part def TripMeter {
        attribute tripDistance : Distance = 0[km];
        port tripResetOut : TripResetPort;

        action def TrackTrip {
            in delta : Distance;
            out trip : Distance;
        }
        action def ResetTripMeter {
            out resetTrip : Distance = 0[km];
        }
    }

    part def NonVolatileStorage {
        attribute storedTotalDistance : Distance = 0[km];
        attribute writeCycles : ScalarValue = 0;
        attribute maxWriteCycles : ScalarValue = 1000000;

        port storageWriteIn : StorageReadPort {
            in storedReading : StoredOdometerReading;
        }
        port storageReadOut : StorageWritePort {
            out storedReading : StoredOdometerReading;
        }

        action def ReadStoredValue {
            out reading : StoredOdometerReading;
        }
        action def WriteStoredValue {
            in reading : StoredOdometerReading;
        }
    }

    // ===== System-Level Part =====
    part def DigitalOdometerSystem {
        satisfy OdometerRequirements::*;

        part wheelSensor : WheelRotationSensor;
        part calcUnit : DistanceCalculationUnit;
        part display : DisplayUnit;
        part tripMeter : TripMeter;
        part nvStorage : NonVolatileStorage;

        // Connections
        connection pulseConnection connect wheelSensor.pulseOut to calcUnit.pulseIn;
        connection distanceConnection connect calcUnit.distanceOut to display.displayIn;
        connection displayCmdConnection connect calcUnit.displayOut to display.displayIn;
        connection storageWriteConnection connect calcUnit.storageWrite to nvStorage.storageWriteIn;
        connection storageReadConnection connect nvStorage.storageReadOut to calcUnit.storageRead;
        connection tripResetConnection connect tripMeter.tripResetOut to calcUnit.tripResetIn;

        // System State Machine
        state def OdometerStateMachine {
            entry; then Off;

            state Off {
                entry; then OffIdle;
                state OffIdle;
                transition powerOn transition offIdle -> Initializing
                    if PowerOnSignal;
            }

            state Initializing {
                entry action LoadStoredData {
                    // Load stored total distance from non-volatile storage
                }
                do action InitializeSystem {
                    // Set totalDistance from stored value
                    // Reset trip distance to zero
                    // Clear pulse buffer
                }
                then Measuring;
            }

            state Measuring {
                entry action StartMeasurement;
                do action ContinuousMeasurement {
                    // Process incoming pulses
                    // Compute incremental distance
                    // Compute current speed
                    // Update total and trip distances
                    // Send data to display
                    // Periodically save to non-volatile storage
                }
                state Idle;
                state Active;
                transition vehicleMoves transition Idle -> Active
                    if PulseReceived;
                transition vehicleStops transition Active -> Idle
                    if NoPulseForDuration;
                transition powerOff transition Idle -> Off
                    if PowerOffSignal;
                transition powerOffActive transition Active -> Off
                    if PowerOffSignal;
                transition tripReset transition Idle -> Idle
                    if TripResetSignal;
            }

            transition initToMeasure transition Initializing -> Measuring
                if InitializationComplete;
        }

        attribute stateMachine : OdometerStateMachine;
    }
}
