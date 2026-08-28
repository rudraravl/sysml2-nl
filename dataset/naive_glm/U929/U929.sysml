package TurnCoordinatorModel {

    import ISQ::*;
    import ScalarValues::*;

    // ---- Value Types with Units ----

    value def AngularRateValue > Real {
        :>> unit = "rad/s";
    }

    value def BankAngleValue > Real {
        :>> unit = "deg";
    }

    value def LateralAccelerationValue > Real {
        :>> unit = "m/s^2";
    }

    value def VoltageValue > Real {
        :>> unit = "V";
    }

    value def FrequencyValue > Real {
        :>> unit = "Hz";
    }

    value def TemperatureValue > Real {
        :>> unit = "degC";
    }

    value def DurationValue > Real {
        :>> unit = "s";
    }

    value def BooleanStatus > Boolean;

    // ---- Item Types ----

    item def GyroMeasurement {
        attribute angularRate : AngularRateValue;
        attribute bankAngle : BankAngleValue;
        attribute valid : BooleanStatus;
        attribute timestamp : DurationValue;
    }

    item def InclinometerMeasurement {
        attribute ballPosition : Real; // normalized -1..1 relative to center
        attribute lateralAccel : LateralAccelerationValue;
        attribute valid : BooleanStatus;
        attribute timestamp : DurationValue;
    }

    item def DisplayCommand {
        attribute airplaneBank : BankAngleValue;
        attribute turnRateIndication : AngularRateValue;
        attribute ballOffset : Real;
        attribute failureFlag : BooleanStatus;
    }

    item def PowerStatus {
        attribute voltage : VoltageValue;
        attribute powerOn : BooleanStatus;
        attribute quality : Real; // 0..1
    }

    item def HealthStatus {
        attribute gyroHealthy : BooleanStatus;
        attribute inclinometerHealthy : BooleanStatus;
        attribute processorHealthy : BooleanStatus;
        attribute displayHealthy : BooleanStatus;
    }

    // ---- Port Definitions ----

    port def PowerInPort {
        in powerStatus : PowerStatus;
    }

    port def GyroOutPort {
        out measurement : GyroMeasurement;
    }

    port def InclinometerOutPort {
        out measurement : InclinometerMeasurement;
    }

    port def ProcessorGyroInPort {
        in measurement : GyroMeasurement;
    }

    port def ProcessorInclinometerInPort {
        in measurement : InclinometerMeasurement;
    }

    port def ProcessorDisplayOutPort {
        out command : DisplayCommand;
    }

    port def DisplayInPort {
        in command : DisplayCommand;
    }

    port def HealthReportPort {
        out health : HealthStatus;
    }

    // ---- Requirements ----

    requirement def TurnCoordinatorFunctionRequirement {
        doc /* The turn coordinator shall display rate of turn and coordination quality. */
        subject tc : TurnCoordinator;
        require {
            attribute coordinated : BooleanStatus;
        }
    }

    requirement def RateGyroscopeRequirement {
        doc /* The rate gyroscope shall measure turn rate and bank angle within specified accuracy. */
        subject gyro : RateGyroscope;
        require {
            attribute angularRateAccuracy : AngularRateValue = 0.5;
            attribute bankAngleAccuracy : BankAngleValue = 2.0;
        }
    }

    requirement def InclinometerRequirement {
        doc /* The inclinometer shall measure lateral acceleration and indicate slip/skid. */
        subject incl : Inclinometer;
        require {
            attribute ballCenterTolerance : Real = 0.05;
        }
    }

    requirement def SignalProcessorRequirement {
        doc /* The signal processor shall filter, scale, and convert sensor inputs into display commands. */
        subject proc : SignalProcessor;
        require {
            attribute processingLatency : DurationValue = 0.05;
        }
    }

    requirement def DisplayRequirement {
        doc /* The display shall present airplane bank symbol and ball position to the pilot. */
        subject disp : InstrumentDisplay;
        require {
            attribute refreshRate : FrequencyValue = 60.0;
        }
    }

    requirement def LifecycleRequirement {
        doc /* The instrument shall implement startup, operational, power loss, and failure modes. */
        subject tc : TurnCoordinator;
        require {
            attribute startupTime : DurationValue = 30.0;
        }
    }

    requirement def SafetyRequirement {
        doc /* The instrument shall not mislead the pilot during internal failure; it shall indicate failure. */
        subject tc : TurnCoordinator;
        require {
            attribute failureIndication : BooleanStatus = true;
        }
    }

    // ---- Parts ----

    part def RateGyroscope {
        port gyroOut : GyroOutPort;
        port powerIn : PowerInPort;

        attribute spinUpTime : DurationValue = 25.0;
        attribute nominalSpinSpeed : FrequencyValue = 10000.0;
        attribute currentSpinSpeed : FrequencyValue;
        attribute calibrated : BooleanStatus = false;

        action spec MeasureMotion {
            in aircraftMotion : AngularRateValue;
            out meas : GyroMeasurement;
            doc /* Continuously sample the aircraft angular rate and bank angle. */
            perform {
                meas.angularRate = aircraftMotion;
                meas.valid = (self.calibrated and self.currentSpinSpeed >= self.nominalSpinSpeed * 0.9);
            }
        }
    }

    part def Inclinometer {
        port inclOut : InclinometerOutPort;

        attribute fluidTemp : TemperatureValue = 20.0;
        attribute ballRestPosition : Real = 0.0;

        action spec MeasureLateralAccel {
            in lateral : LateralAccelerationValue;
            out meas : InclinometerMeasurement;
            perform {
                meas.lateralAccel = lateral;
                meas.ballPosition = lateral / 9.81;
                if (meas.ballPosition > 1.0) { meas.ballPosition = 1.0; }
                if (meas.ballPosition < -1.0) { meas.ballPosition = -1.0; }
                meas.valid = true;
            }
        }
    }

    part def SignalProcessor {
        port gyroIn : ProcessorGyroInPort;
        port inclIn : ProcessorInclinometerInPort;
        port displayOut : ProcessorDisplayOutPort;
        port powerIn : PowerInPort;
        port healthOut : HealthReportPort;

        attribute filterGain : Real = 0.8;
        attribute scaleTurnRate : Real = 1.0;
        attribute scaleBankAngle : Real = 1.0;
        attribute processorActive : BooleanStatus = false;

        action spec ProcessData {
            in gyro : GyroMeasurement;
            in incl : InclinometerMeasurement;
            out cmd : DisplayCommand;
            perform {
                if (gyro.valid and incl.valid) {
                    cmd.airplaneBank = gyro.bankAngle * self.scaleBankAngle;
                    cmd.turnRateIndication = gyro.angularRate * self.scaleTurnRate;
                    cmd.ballOffset = incl.ballPosition;
                    cmd.failureFlag = false;
                } else {
                    cmd.airplaneBank = 0.0;
                    cmd.turnRateIndication = 0.0;
                    cmd.ballOffset = 0.0;
                    cmd.failureFlag = true;
                }
            }
        }
    }

    part def InstrumentDisplay {
        port displayIn : DisplayInPort;
        port powerIn : PowerInPort;

        attribute refreshRate : FrequencyValue = 60.0;
        attribute airplaneBankPosition : BankAngleValue = 0.0;
        attribute ballPosition : Real = 0.0;
        attribute failureFlag : BooleanStatus = false;
        attribute backlit : BooleanStatus = false;

        action spec RenderDisplay {
            in cmd : DisplayCommand;
            perform {
                self.airplaneBankPosition = cmd.airplaneBank;
                self.ballPosition = cmd.ballOffset;
                self.failureFlag = cmd.failureFlag;
            }
        }

        action spec ShowFailFlag {
            perform {
                self.failureFlag = true;
                self.airplaneBankPosition = 0.0;
                self.ballPosition = 0.0;
            }
        }
    }

    // ---- Top-level Turn Coordinator ----

    part def TurnCoordinator {
        port powerIn : PowerInPort;
        port healthOut : HealthReportPort;

        attribute startupDuration : DurationValue = 30.0;
        attribute operational : BooleanStatus = false;
        attribute failed : BooleanStatus = false;

        part rateGyroscope : RateGyroscope {
            port gyroOut : GyroOutPort;
            port powerIn : PowerInPort;
        }

        part inclinometer : Inclinometer {
            port inclOut : InclinometerOutPort;
        }

        part signalProcessor : SignalProcessor {
            port gyroIn : ProcessorGyroInPort;
            port inclIn : ProcessorInclinometerInPort;
            port displayOut : ProcessorDisplayOutPort;
            port powerIn : PowerInPort;
            port healthOut : HealthReportPort;
        }

        part instrumentDisplay : InstrumentDisplay {
            port displayIn : DisplayInPort;
            port powerIn : PowerInPort;
        }

        // ---- Connections ----

        connection def PowerToGyro {
            :>> powerIn : PowerInPort;
            :>> powerOut : PowerInPort;
            bind powerIn.powerStatus <=> powerOut.powerStatus;
        }

        connection def PowerToProcessor {
            :>> powerIn : PowerInPort;
            :>> powerOut : PowerInPort;
            bind powerIn.powerStatus <=> powerOut.powerStatus;
        }

        connection powerToGyro : PowerToGyro {
            :>> powerIn = self.powerIn;
            :>> powerOut = rateGyroscope.powerIn;
        }

        connection powerToProcessor : PowerToProcessor {
            :>> powerIn = self.powerIn;
            :>> powerOut = signalProcessor.powerIn;
        }

        connection powerToDisplay : PowerToProcessor {
            :>> powerIn = self.powerIn;
            :>> powerOut = instrumentDisplay.powerIn;
        }

        connection gyroToProcessor {
            bind rateGyroscope.gyroOut.measurement <=> signalProcessor.gyroIn.measurement;
        }

        connection inclToProcessor {
            bind inclinometer.inclOut.measurement <=> signalProcessor.inclIn.measurement;
        }

        connection processorToDisplay {
            bind signalProcessor.displayOut.command <=> instrumentDisplay.displayIn.command;
        }

        connection healthReport {
            bind signalProcessor.healthOut.health <=> self.healthOut.health;
        }

        // ---- State Machine ----

        state machine def TurnCoordinatorLifecycle {
            attribute elapsedStartup : DurationValue = 0.0;

            state Off {
                entry {
                    self.operational = false;
                    self.failed = false;
                    rateGyroscope.currentSpinSpeed = 0.0;
                    rateGyroscope.calibrated = false;
                    signalProcessor.processorActive = false;
                    instrumentDisplay.backlit = false;
                }
                do {
                    if (self.powerIn.powerStatus.powerOn) {
                        send Start;
                    }
                }
            }

            state Startup {
                entry {
                    elapsedStartup = 0.0;
                    rateGyroscope.calibrated = false;
                    signalProcessor.processorActive = false;
                }
                do {
                    rateGyroscope.currentSpinSpeed = rateGyroscope.currentSpinSpeed + (rateGyroscope.nominalSpinSpeed / 25.0);
                    elapsedStartup = elapsedStartup + 1.0;
                    if (rateGyroscope.currentSpinSpeed >= rateGyroscope.nominalSpinSpeed * 0.95) {
                        rateGyroscope.calibrated = true;
                    }
                    if (elapsedStartup >= self.startupDuration and rateGyroscope.calibrated) {
                        send OperationalMode;
                    }
                }
            }

            state Operational {
                entry {
                    self.operational = true;
                    self.failed = false;
                    signalProcessor.processorActive = true;
                    instrumentDisplay.backlit = true;
                }
                do {
                    rateGyroscope.MeasureMotion();
                    inclinometer.MeasureLateralAccel();
                    signalProcessor.ProcessData();
                    instrumentDisplay.RenderDisplay();
                    if (not self.powerIn.powerStatus.powerOn) {
                        send PowerLost;
                    }
                    if (signalProcessor.healthOut.health.gyroHealthy == false or
                        signalProcessor.healthOut.health.inclinometerHealthy == false or
                        signalProcessor.healthOut.health.processorHealthy == false or
                        signalProcessor.healthOut.health.displayHealthy == false) {
                        send FailureDetected;
                    }
                }
            }

            state PowerLoss {
                entry {
                    self.operational = false;
                    instrumentDisplay.backlit = false;
                }
                do {
                    instrumentDisplay.ShowFailFlag();
                    if (self.powerIn.powerStatus.powerOn) {
                        send Start;
                    }
                }
            }

            state Failure {
                entry {
                    self.failed = true;
                    self.operational = false;
                }
                do {
                    instrumentDisplay.ShowFailFlag();
                }
            }

            transition off_to_startup first Off then Startup
                when self.powerIn.powerStatus.powerOn
                trigger Start;

            transition startup_to_op first Startup then Operational
                trigger OperationalMode;

            transition op_to_powerloss first Operational then PowerLoss
                when not self.powerIn.powerStatus.powerOn
                trigger PowerLost;

            transition op_to_failure first Operational then Failure
                trigger FailureDetected;

            transition powerloss_to_off first PowerLoss then Off
                when not self.powerIn.powerStatus.powerOn;

            transition failure_to_off first Failure then Off
                when not self.powerIn.powerStatus.powerOn;
        }

        // ---- Requirements Satisfaction ----

        satisfy TurnCoordinatorFunctionRequirement {
            subject = self;
            require coordinated = (self.operational and not self.failed);
        }

        satisfy RateGyroscopeRequirement {
            subject = rateGyroscope;
        }

        satisfy InclinometerRequirement {
            subject = inclinometer;
        }

        satisfy SignalProcessorRequirement {
            subject = signalProcessor;
        }

        satisfy DisplayRequirement {
            subject = instrumentDisplay;
        }

        satisfy LifecycleRequirement {
            subject = self;
            require startupTime = self.startupDuration;
        }

        satisfy SafetyRequirement {
            subject = self;
            require failureIndication = self.failed;
        }
    }

}
