// Create a model for a drone with a battery, a motor, and an altitude sensor.
package DroneSystem {
    
    package Domain {
        package Units {
            unit m;
            unit V;
            unit A;
            unit Ah;
            unit '%';
            unit rpm;
        }

        package Types {
            import Units::*;
            
            value def Altitude { attribute value : Real[1] units m; }
            value def Voltage { attribute value : Real[1] units V; }
            value def Current { attribute value : Real[1] units A; }
            value def Capacity { attribute value : Real[1] units Ah; }
            value def ChargeState { attribute value : Real[1] units '%'; }
            value def RotationalSpeed { attribute value : Real[1] units rpm; }
        }

        package Items {
            import Types::*;

            item def PowerFlow {
                inout voltage : Voltage;
                inout current : Current;
            }

            item def AltitudeSignal {
                out altitude : Altitude;
            }

            item def MotorControlSignal {
                in speed : RotationalSpeed;
            }

            item def BatteryStatusSignal {
                out charge : ChargeState;
                out voltage : Voltage;
            }
        }
    }

    package Library {
        import Domain::Items::*;
        import Domain::Types::*;

        part def Battery {
            attribute nominalVoltage : Voltage = 14.8;
            attribute capacity : Capacity = 5.2;
            attribute stateOfCharge : ChargeState = 100.0;
            port powerPort : PowerFlow;

            action discharge(in currentDraw : Current) {
                // A simplified model where state of charge decreases over time based on load.
            }
        }

        part def BrushlessDCMotor {
            port powerIn : PowerFlow;
            port commandIn : MotorControlSignal;
            attribute currentSpeed : RotationalSpeed;

            perform action setSpeed {
                in commandedSpeed : RotationalSpeed from commandIn.speed;
                first then {
                    out currentSpeed = commandedSpeed;
                }
            }
        }

        part def BarometricAltimeter {
            port dataOut : AltitudeSignal;
            attribute currentAltitude : Altitude;

            perform action measureAltitude {
                first then {
                    // Simulate measurement of altitude.
                    out currentAltitude = 100.0;
                    out dataOut.altitude = currentAltitude;
                }
            }
        }

        part def PowerManagementUnit {
            port batteryIn : PowerFlow;
            port regulatedPowerOut[5] : PowerFlow;
            port statusOut : BatteryStatusSignal;

            perform action monitorAndDistribute {
                in batteryVoltage : Voltage from batteryIn.voltage;
                out statusOut.voltage = batteryVoltage;
                // In a real system, charge would be calculated from voltage and current.
                out statusOut.charge = 95.0; 
            }
        }

        part def FlightController {
            port powerIn : PowerFlow;
            port altitudeDataIn : AltitudeSignal;
            port batteryStatusIn : BatteryStatusSignal;
            port motorCommandsOut[4] : MotorControlSignal;

            attribute targetAltitude : Altitude = 100.0;
            attribute isArmed : Boolean = false;

            state machine FlightMode {
                initial state Disarmed;
                state Armed;
                state Flying;
                state Landing;

                transition from Disarmed to Armed on arm { isArmed = true; };
                transition from Armed to Flying on takeoff;
                transition from Flying to Landing on land;
                transition from Landing to Armed;
                transition from Armed to Disarmed on disarm { isArmed = false; };

                state Flying {
                    perform action maintainAltitude;
                }
            }

            action maintainAltitude {
                in currentAltitude : Altitude from altitudeDataIn.altitude;
                in currentCharge : ChargeState from batteryStatusIn.charge;
                out motorSpeeds[4] : RotationalSpeed to motorCommandsOut.speed;

                first then if currentCharge.value > 20.0 {
                    if currentAltitude.value < targetAltitude.value - 0.5 {
                        motorSpeeds = (2200.0, 2200.0, 2200.0, 2200.0);
                    } else if currentAltitude.value > targetAltitude.value + 0.5 {
                        motorSpeeds = (1800.0, 1800.0, 1800.0, 1800.0);
                    } else {
                        motorSpeeds = (2000.0, 2000.0, 2000.0, 2000.0);
                    }
                } else {
                    accept land;
                }
            }
        }
    }

    package System {
        import Library::*;

        part drone {
            part battery : Battery;
            part motor1 : BrushlessDCMotor;
            part motor2 : BrushlessDCMotor;
            part motor3 : BrushlessDCMotor;
            part motor4 : BrushlessDCMotor;
            part altimeter : BarometricAltimeter;
            part pmu : PowerManagementUnit;
            part fc : FlightController;

            connect battery.powerPort to pmu.batteryIn;
            connect pmu.regulatedPowerOut[1] to motor1.powerIn;
            connect pmu.regulatedPowerOut[2] to motor2.powerIn;
            connect pmu.regulatedPowerOut[3] to motor3.powerIn;
            connect pmu.regulatedPowerOut[4] to motor4.powerIn;
            connect pmu.regulatedPowerOut[5] to fc.powerIn;

            connect pmu.statusOut to fc.batteryStatusIn;
            connect altimeter.dataOut to fc.altitudeDataIn;
            connect fc.motorCommandsOut[1] to motor1.commandIn;
            connect fc.motorCommandsOut[2] to motor2.commandIn;
            connect fc.motorCommandsOut[3] to motor3.commandIn;
            connect fc.motorCommandsOut[4] to motor4.commandIn;
        }
    }

    package Requirements {
        import System::drone;
        import Library::BarometricAltimeter;

        requirement AltitudeHold {
            doc "The drone shall maintain its altitude within +/- 1 meter of a setpoint in calm wind conditions.";
            subject d : drone;
        }

        requirement SensorAccuracy {
            doc "The barometric altimeter shall have a vertical resolution of 0.5 meters or better.";
            subject alt : BarometricAltimeter;
        }

        #derivation connection {
            end #original ::> AltitudeHold;
            end #derive ::> SensorAccuracy;
        }

        satisfy AltitudeHold by drone.fc.FlightMode.Flying;
    }
}
