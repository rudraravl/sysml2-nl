// Create a model for a drone with a battery, a motor, and an altitude sensor.
package DroneSystem {
    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    package CustomUnits {
        private import SI::*;
        unit mAh = (mA * h);
    }
    import CustomUnits::*;

    // --- Value and Enumeration Definitions ---

    attribute def VoltageValue :> Real {
        attribute :>> num : Real;
        attribute unit : VoltageUnit = V;
    }

    attribute def CapacityValue :> Real {
        attribute :>> num : Real;
        attribute unit : ElectricChargeUnit = mAh;
    }

    attribute def AltitudeValue :> LengthValue;

    attribute def RPMValue :> Real {
        attribute :>> num : Real;
    }

    enum def BatteryStateKind {
        enum full;
        enum normal;
        enum low;
        enum critical;
    }

    // --- Port Definitions ---

    port def PowerPort {
        attribute voltage : VoltageValue;
    }

    port def SensorDataPort {
        out attribute altitude : AltitudeValue;
    }

    port def MotorControlPort {
        in attribute targetRPM : RPMValue;
        out attribute actualRPM : RPMValue;
    }

    // --- Component Definitions ---

    part def Battery {
        attribute capacity : CapacityValue;
        attribute currentCharge : CapacityValue;
        attribute voltage : VoltageValue;
        attribute stateOfCharge : Real; // Ratio from 0.0 to 1.0
        attribute state : BatteryStateKind;

        port powerOut : PowerPort {
            out attribute :>> voltage;
        }

        state machine chargeState {
            entry; then full;

            state full;
            transition from full to normal
                when stateOfCharge < 0.9;

            state normal;
            transition from normal to low
                when stateOfCharge < 0.3;

            state low;
            transition from low to critical
                when stateOfCharge < 0.1;
        }
    }

    part def Motor {
        attribute maxRPM : RPMValue;
        attribute currentRPM : RPMValue;

        port powerIn : PowerPort {
            in attribute :>> voltage;
        }

        port controlIn : MotorControlPort {
            in attribute :>> targetRPM;
            out attribute actualRPM = currentRPM;
        }

        state machine motorState {
            entry; then off;
            state off;
            state running;

            transition from off to running
                when controlIn.targetRPM.num > 0.0;

            transition from running to off
                when controlIn.targetRPM.num == 0.0;
        }
    }

    part def AltitudeSensor {
        attribute currentAltitude : AltitudeValue;
        attribute accuracy : LengthValue;

        port powerIn : PowerPort {
            in attribute :>> voltage;
        }

        port dataOut : SensorDataPort {
            out attribute altitude = currentAltitude;
        }

        perform action measureAltitude {
            out altitudeReading : AltitudeValue;
            first start;
            then action readSensor;
            then action processData {
                out altitudeReading = currentAltitude;
            }
            then done;
        }
    }

    part def PowerDistributionUnit {
        port powerIn : PowerPort;
        port motorPowerOut[4] : PowerPort;
        port avionicsPowerOut : PowerPort;

        flow from powerIn to motorPowerOut;
        flow from powerIn to avionicsPowerOut;
    }

    part def FlightController {
        attribute targetAltitude : AltitudeValue;

        port powerIn : PowerPort;

        port altitudeIn : SensorDataPort {
            in attribute :>> altitude;
        }

        port motorControlOut[4] : MotorControlPort {
            out attribute :>> targetRPM;
        }

        port batteryStatusIn {
            in attribute chargeState : BatteryStateKind;
        }

        perform action maintainAltitude {
            in currentAlt : AltitudeValue;
            in targetAlt : AltitudeValue;
            out motorRPMs[4] : RPMValue;

            first start;
            then action calculateError {
                in current :> currentAlt;
                in target :> targetAlt;
                out error : Real;
            }
            then action computeMotorSpeeds {
                in altitudeError : Real;
                out speeds[4] :> motorRPMs;
            }
            then done;
        }
    }

    // --- Drone Assembly ---

    part drone {
        part battery : Battery {
            :>> capacity.num = 5000.0;
            :>> voltage.num = 14.8;
        }

        part motors[4] : Motor {
            :>> maxRPM.num = 8500.0;
        }

        part altitudeSensor : AltitudeSensor {
            :>> accuracy.num = 0.5;
            :>> accuracy.unit = m;
        }

        part powerDistro : PowerDistributionUnit;

        part controller : FlightController;

        // Power Connections
        connect battery.powerOut to powerDistro.powerIn;
        for i in 1..4 {
            connect powerDistro.motorPowerOut[i] to motors[i].powerIn;
        }
        connect powerDistro.avionicsPowerOut to controller.powerIn;
        connect powerDistro.avionicsPowerOut to altitudeSensor.powerIn;

        // Data and Control Connections
        connect altitudeSensor.dataOut to controller.altitudeIn;
        for i in 1..4 {
            connect controller.motorControlOut[i] to motors[i].controlIn;
        }
        
        // Information flow for battery status
        bind controller.batteryStatusIn.chargeState = battery.state;
    }

    // --- Requirements ---

    package Requirements {
        requirement <'DR-01'> altitudeHold {
            doc "The drone shall be capable of maintaining a stable altitude.";
            subject d :>> drone;
        }

        requirement <'DR-01.1'> hoverAccuracy refines altitudeHold {
            doc "The drone's altitude must remain within +/- 0.5m of the target altitude during hover.";
            subject d :>> drone;
            assert constraint {
                abs(d.altitudeSensor.currentAltitude.num - d.controller.targetAltitude.num) <= 0.5
            }
        }

        requirement <'DR-02'> batteryCapacity {
            doc "The battery shall have a minimum capacity of 5000 mAh.";
            subject b :>> drone.battery;
            assert constraint {
                b.capacity.num >= 5000.0
            }
        }

        requirement <'DR-03'> motorPerformance {
            doc "Each motor shall be capable of reaching at least 8500 RPM.";
            subject m :>> drone.motors; // Subject is the set of motors
            assert constraint {
                // This constraint applies to all motors in the set
                m.maxRPM.num >= 8500.0
            }
        }

        satisfy hoverAccuracy by drone.controller.maintainAltitude;
        satisfy batteryCapacity by drone.battery;
        satisfy motorPerformance by drone.motors;
    }
}
