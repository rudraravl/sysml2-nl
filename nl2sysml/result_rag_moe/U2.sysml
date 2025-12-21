// Create a model for a drone with a battery, a motor, and an altitude sensor.
package DroneSystem {
    import ScalarValues::*;
    import ISQ::*;
    import SI::*;
    
    value def VoltageValue :> Real {
        attribute :>> num : Real;
    }
    
    value def CurrentValue :> Real {
        attribute :>> num : Real;
    }
    
    value def CapacityValue :> Real {
        attribute :>> num : Real;
    }
    
    value def AltitudeValue :> Real {
        attribute :>> num : Real;
    }
    
    value def RPMValue :> Real {
        attribute :>> num : Real;
    }
    
    value def PowerValue :> Real {
        attribute :>> num : Real;
    }
    
    value def PercentValue :> Real {
        attribute :>> num : Real;
    }
    
    enum def BatteryStateKind {
        enum full;
        enum normal;
        enum low;
        enum critical;
        enum depleted;
    }
    
    enum def MotorStateKind {
        enum off;
        enum starting;
        enum running;
        enum stopping;
        enum fault;
    }
    
    enum def SensorStateKind {
        enum idle;
        enum measuring;
        enum transmitting;
    }
    
    item def ElectricalPower {
        attribute voltage : VoltageValue;
        attribute current : CurrentValue;
    }
    
    item def AltitudeData {
        attribute altitude : AltitudeValue;
        attribute timestamp : Real;
    }
    
    item def MotorCommand {
        attribute targetRPM : RPMValue;
        attribute enabled : Boolean;
    }
    
    part def Battery {
        attribute capacity : CapacityValue;
        attribute currentCharge : CapacityValue;
        attribute nominalVoltage : VoltageValue;
        attribute maxCurrent : CurrentValue;
        attribute stateOfCharge : PercentValue;
        
        port powerOut {
            out item electricalPower : ElectricalPower;
        }
        
        port statusPort {
            out attribute batteryState : BatteryStateKind;
            out attribute chargeLevel : PercentValue;
        }
        
        state batteryStateMachine {
            entry; then full;
            
            state full {
                entry assign batteryState = BatteryStateKind::full;
            }
            
            state normal {
                entry assign batteryState = BatteryStateKind::normal;
            }
            
            state low {
                entry assign batteryState = BatteryStateKind::low;
            }
            
            state critical {
                entry assign batteryState = BatteryStateKind::critical;
            }
            
            state depleted {
                entry assign batteryState = BatteryStateKind::depleted;
            }
            
            transition full_to_normal
                first full
                accept at stateOfCharge.num < 90.0
                then normal;
                
            transition normal_to_low
                first normal
                accept at stateOfCharge.num < 30.0
                then low;
                
            transition low_to_critical
                first low
                accept at stateOfCharge.num < 15.0
                then critical;
                
            transition critical_to_depleted
                first critical
                accept at stateOfCharge.num < 5.0
                then depleted;
        }
        
        action dischargeBattery {
            in powerDemand : PowerValue;
            out updatedCharge : CapacityValue;
            
            first start;
            then action calculateDischarge {
                in demand :>> powerDemand;
                out newCharge : CapacityValue;
            }
            then action updateState {
                in charge :>> calculateDischarge.newCharge;
            }
            then done;
        }
    }
    
    part def Motor {
        attribute maxRPM : RPMValue;
        attribute currentRPM : RPMValue;
        attribute powerConsumption : PowerValue;
        attribute efficiency : PercentValue;
        attribute minOperatingVoltage : VoltageValue;
        
        port powerIn {
            in item electricalPower : ElectricalPower;
        }
        
        port controlPort {
            in item controlSignal : MotorCommand;
        }
        
        port statusPort {
            out attribute motorState : MotorStateKind;
            out attribute rpm : RPMValue;
        }
        
        state motorStateMachine {
            entry; then off;
            
            state off {
                entry assign motorState = MotorStateKind::off;
                entry assign currentRPM.num = 0.0;
            }
            
            state starting {
                entry assign motorState = MotorStateKind::starting;
                do action rampUp {
                    first start;
                    then action increaseRPM;
                    then done;
                }
            }
            
            state running {
                entry assign motorState = MotorStateKind::running;
                do action maintainSpeed {
                    first start;
                    then action regulateRPM;
                    then done;
                }
            }
            
            state stopping {
                entry assign motorState = MotorStateKind::stopping;
                do action rampDown {
                    first start;
                    then action decreaseRPM;
                    then done;
                }
            }
            
            state fault {
                entry assign motorState = MotorStateKind::fault;
            }
            
            transition off_to_starting
                first off
                accept controlSignal.enabled == true
                then starting;
                
            transition starting_to_running
                first starting
                accept at currentRPM.num >= controlSignal.targetRPM.num * 0.95
                then running;
                
            transition running_to_stopping
                first running
                accept controlSignal.enabled == false
                then stopping;
                
            transition stopping_to_off
                first stopping
                accept at currentRPM.num <= 0.0
                then off;
                
            transition any_to_fault
                first off, starting, running, stopping
                accept electricalPower.voltage.num < minOperatingVoltage.num
                then fault;
        }
    }
    
    part def AltitudeSensor {
        attribute measurementRange : AltitudeValue;
        attribute accuracy : AltitudeValue;
        attribute currentAltitude : AltitudeValue;
        attribute samplingRate : Real;
        
        port powerIn {
            in item electricalPower : ElectricalPower;
        }
        
        port dataOut {
            out item sensorData : AltitudeData;
        }
        
        port statusPort {
            out attribute sensorState : SensorStateKind;
        }
        
        action measureAltitude {
            out measurement : AltitudeData;
            
            first start;
            then action readSensor {
                out rawValue : AltitudeValue;
            }
            then action calibrateReading {
                in raw :>> readSensor.rawValue;
                out calibrated : AltitudeValue;
            }
            then action packageData {
                in altitude :>> calibrateReading.calibrated;
                out data :>> measurement;
            }
            then done;
        }
        
        state sensorStateMachine {
            entry; then idle;
            
            state idle {
                entry assign sensorState = SensorStateKind::idle;
            }
            
            state measuring {
                entry assign sensorState = SensorStateKind::measuring;
                do measureAltitude;
            }
            
            state transmitting {
                entry assign sensorState = SensorStateKind::transmitting;
                do action sendData {
                    first start;
                    then action transmit;
                    then done;
                }
            }
            
            transition idle_to_measuring
                first idle
                then measuring;
                
            transition measuring_to_transmitting
                first measuring
                then transmitting;
                
            transition transmitting_to_idle
                first transmitting
                then idle;
        }
    }
    
    part def DroneController {
        attribute targetAltitude : AltitudeValue;
        attribute controlGain : Real;
        
        port batteryStatusIn {
            in attribute batteryState : BatteryStateKind;
            in attribute chargeLevel : PercentValue;
        }
        
        port motorStatusIn {
            in attribute motorState : MotorStateKind;
            in attribute rpm : RPMValue;
        }
        
        port altitudeDataIn {
            in item sensorData : AltitudeData;
        }
        
        port motorControlOut {
            out item controlSignal : MotorCommand;
        }
        
        action controlLoop {
            first start;
            then action readSensors {
                out altitude : AltitudeValue;
                out batteryLevel : PercentValue;
            }
            then action computeControl {
                in currentAltitude :>> readSensors.altitude;
                in battery :>> readSensors.batteryLevel;
                out motorCommand : MotorCommand;
            }
            then action sendCommands {
                in command :>> computeControl.motorCommand;
            }
            loop back computeControl;
        }
    }
    
    part drone {
        part battery : Battery {
            :>> capacity.num = 5000.0;
            :>> currentCharge.num = 5000.0;
            :>> nominalVoltage.num = 14.8;
            :>> maxCurrent.num = 30.0;
            :>> stateOfCharge.num = 100.0;
        }
        
        part motor : Motor {
            :>> maxRPM.num = 8000.0;
            :>> currentRPM.num = 0.0;
            :>> powerConsumption.num = 150.0;
            :>> efficiency.num = 85.0;
            :>> minOperatingVoltage.num = 10.0;
        }
        
        part altitudeSensor : AltitudeSensor {
            :>> measurementRange.num = 500.0;
            :>> accuracy.num = 0.5;
            :>> currentAltitude.num = 0.0;
            :>> samplingRate = 10.0;
        }
        
        part controller : DroneController {
            :>> targetAltitude.num = 100.0;
            :>> controlGain = 0.5;
        }
        
        connect battery.powerOut to motor.powerIn;
        connect battery.powerOut to altitudeSensor.powerIn;
        connect battery.statusPort to controller.batteryStatusIn;
        connect motor.statusPort to controller.motorStatusIn;
        connect altitudeSensor.dataOut to controller.altitudeDataIn;
        connect controller.motorControlOut to motor.controlPort;
    }
    
    requirement <'REQ-001'> droneOperationalRequirement {
        doc /* The drone shall maintain stable operation with 
             * integrated battery, motor, and altitude sensing.
             */
        subject drone : drone;
        
        require batteryCapacityReq;
        require motorPerformanceReq;
        require altitudeSensingReq;
    }
    
    requirement <'REQ-002'> batteryCapacityReq {
        doc /* The battery shall provide sufficient capacity 
             * for extended flight operations.
             */
        subject battery :>> drone.battery;
        
        assert constraint {
            battery.capacity.num >= 4000.0
        }
    }
    
    requirement <'REQ-003'> motorPerformanceReq {
        doc /* The motor shall achieve operational RPM range 
             * for flight control.
             */
        subject motor :>> drone.motor;
        
        assert constraint {
            motor.maxRPM.num >= 6000.0
        }
    }
    
    requirement <'REQ-004'> altitudeSensingReq {
        doc /* The altitude sensor shall provide accurate 
             * altitude measurements within operational range.
             */
        subject sensor :>> drone.altitudeSensor;
        
        assert constraint {
            sensor.accuracy.num <= 1.0 and
            sensor.measurementRange.num >= 300.0
        }
    }
    
    satisfy droneOperationalRequirement by drone;
}
