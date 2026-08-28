package 'BEAM Photovore Robot' {
    private import ScalarValues::*;
    
    package Definitions {
        private import ScalarValues::*;
        
        attribute def LightIntensity :> Real;
        attribute def Voltage :> Real;
        attribute def Capacitance :> Real;
        attribute def Torque :> Real;
        attribute def ThresholdVoltage :> Voltage;
        
        item def Light {
            attribute intensity : LightIntensity;
        }
        
        item def ElectricalEnergy {
            attribute charge : Real;
            attribute potential : Voltage;
        }
        
        item def MechanicalEnergy {
            attribute torque : Torque;
        }
        
        port def OpticalPort {
            in light : Light;
        }
        
        port def ElectricalPort {
            inout energy : ElectricalEnergy;
        }
        
        port def MechanicalPort {
            out energy : MechanicalEnergy;
        }
        
        part def Photoresistor {
            port opticalIn : OpticalPort;
            attribute lightIntensity : LightIntensity;
        }
        
        part def SolarCell {
            port opticalIn : OpticalPort;
            port electricalOut : ElectricalPort;
        }
        
        part def Capacitor {
            port electricalIn : ElectricalPort;
            port electricalOut : ElectricalPort;
            attribute capacitance : Capacitance = 0.1;
            attribute voltage : Voltage = 0.0;
        }
        
        part def AnalogTriggerCircuit {
            port monitorIn : ElectricalPort;
            port triggerOut : ElectricalPort;
            attribute threshold : ThresholdVoltage = 5.0;
            attribute trigger : Boolean = false;
        }
        
        part def DCMotor {
            port electricalIn : ElectricalPort;
            port mechanicalOut : MechanicalPort;
            attribute torque : Torque;
        }
        
        part def Wheel {
            port mechanicalIn : MechanicalPort;
            attribute torque : Torque;
        }
        
        action def 'Harvest Energy' {
            in light : Light;
            out energy : ElectricalEnergy;
        }
        
        action def 'Store Energy' {
            in energy : ElectricalEnergy;
            out storedEnergy : ElectricalEnergy;
        }
        
        action def 'Monitor Charge' {
            in storedEnergy : ElectricalEnergy;
            in threshold : ThresholdVoltage;
            out trigger : Boolean;
        }
        
        action def 'Discharge Capacitor' {
            in trigger : Boolean;
            out burst : ElectricalEnergy;
        }
        
        action def 'Drive Motor' {
            in burst : ElectricalEnergy;
            out mechanicalEnergy : MechanicalEnergy;
        }
        
        action def 'Operate Side' {
            in light : Light;
            in threshold : ThresholdVoltage;
            out mechanicalEnergy : MechanicalEnergy;
        }
        
        action def 'Operate Photovore' {
            in leftLight : Light;
            in rightLight : Light;
            in leftThreshold : ThresholdVoltage;
            in rightThreshold : ThresholdVoltage;
            out leftMechanicalEnergy : MechanicalEnergy;
            out rightMechanicalEnergy : MechanicalEnergy;
        }
        
        part def PhotovoreSide {
            part sensor : Photoresistor;
            part solarCell : SolarCell;
            part capacitor : Capacitor;
            part triggerCircuit : AnalogTriggerCircuit;
            part motor : DCMotor;
            part wheel : Wheel;
            
            port lightIn : OpticalPort;
            port mechanicalOut : MechanicalPort;
            
            connect lightIn to sensor.opticalIn;
            connect lightIn to solarCell.opticalIn;
            connect solarCell.electricalOut to capacitor.electricalIn;
            connect capacitor.electricalOut to triggerCircuit.monitorIn;
            connect triggerCircuit.triggerOut to motor.electricalIn;
            connect motor.mechanicalOut to wheel.mechanicalIn;
            connect motor.mechanicalOut to mechanicalOut;
        }
        
        part def PhotovoreRobot {
            doc /* A BEAM Photovore Robot seeks light using analog electronics and a charge-discharge cycle. */
            part leftSide : PhotovoreSide;
            part rightSide : PhotovoreSide;
            
            port leftLightIn : OpticalPort;
            port rightLightIn : OpticalPort;
            port leftMechanicalOut : MechanicalPort;
            port rightMechanicalOut : MechanicalPort;
            
            connect leftLightIn to leftSide.lightIn;
            connect rightLightIn to rightSide.lightIn;
            connect leftSide.mechanicalOut to leftMechanicalOut;
            connect rightSide.mechanicalOut to rightMechanicalOut;
        }
    }
    
    package Usages {
        private import Definitions::*;
        
        part robot : PhotovoreRobot;
        
        action 'operate photovore' : 'Operate Photovore' {
            in leftLight : Light;
            in rightLight : Light;
            in leftThreshold : ThresholdVoltage;
            in rightThreshold : ThresholdVoltage;
            out leftMechanicalEnergy : MechanicalEnergy;
            out rightMechanicalEnergy : MechanicalEnergy;
            
            action 'operate left side' : 'Operate Side' {
                in light = 'operate photovore'.leftLight;
                in threshold = 'operate photovore'.leftThreshold;
                out mechanicalEnergy : MechanicalEnergy;
                
                loop {
                    action 'harvest energy' : 'Harvest Energy' {
                        in light = 'operate left side'.light;
                        out energy : ElectricalEnergy;
                    }
                    flow 'harvest energy'.energy to 'store energy'.energy;
                    action 'store energy' : 'Store Energy' {
                        in energy : ElectricalEnergy;
                        out storedEnergy : ElectricalEnergy;
                    }
                    flow 'store energy'.storedEnergy to 'monitor charge'.storedEnergy;
                    action 'monitor charge' : 'Monitor Charge' {
                        in storedEnergy : ElectricalEnergy;
                        in threshold = 'operate left side'.threshold;
                        out trigger : Boolean;
                    }
                    then if 'monitor charge'.trigger {
                        action 'discharge capacitor' : 'Discharge Capacitor' {
                            in trigger = 'monitor charge'.trigger;
                            out burst : ElectricalEnergy;
                        }
                        flow 'discharge capacitor'.burst to 'drive motor'.burst;
                        action 'drive motor' : 'Drive Motor' {
                            in burst : ElectricalEnergy;
                            out mechanicalEnergy : MechanicalEnergy;
                        }
                        bind 'operate left side'.mechanicalEnergy = 'drive motor'.mechanicalEnergy;
                    }
                }
            }
            
            bind leftMechanicalEnergy = 'operate left side'.mechanicalEnergy;
            
            action 'operate right side' : 'Operate Side' {
                in light = 'operate photovore'.rightLight;
                in threshold = 'operate photovore'.rightThreshold;
                out mechanicalEnergy : MechanicalEnergy;
                
                loop {
                    action 'harvest energy' : 'Harvest Energy' {
                        in light = 'operate right side'.light;
                        out energy : ElectricalEnergy;
                    }
                    flow 'harvest energy'.energy to 'store energy'.energy;
                    action 'store energy' : 'Store Energy' {
                        in energy : ElectricalEnergy;
                        out storedEnergy : ElectricalEnergy;
                    }
                    flow 'store energy'.storedEnergy to 'monitor charge'.storedEnergy;
                    action 'monitor charge' : 'Monitor Charge' {
                        in storedEnergy : ElectricalEnergy;
                        in threshold = 'operate right side'.threshold;
                        out trigger : Boolean;
                    }
                    then if 'monitor charge'.trigger {
                        action 'discharge capacitor' : 'Discharge Capacitor' {
                            in trigger = 'monitor charge'.trigger;
                            out burst : ElectricalEnergy;
                        }
                        flow 'discharge capacitor'.burst to 'drive motor'.burst;
                        action 'drive motor' : 'Drive Motor' {
                            in burst : ElectricalEnergy;
                            out mechanicalEnergy : MechanicalEnergy;
                        }
                        bind 'operate right side'.mechanicalEnergy = 'drive motor'.mechanicalEnergy;
                    }
                }
            }
            
            bind rightMechanicalEnergy = 'operate right side'.mechanicalEnergy;
        }
    }
    
    package Requirements {
        private import Definitions::*;
        private import Usages::*;
        
        requirement <'REQ-1'> 'Light to Motion Conversion' {
            doc /* The robot shall convert light energy into mechanical motion. */
            subject robot : PhotovoreRobot;
        }
        
        requirement <'REQ-2'> 'Autonomous Analog Operation' {
            doc /* The robot shall operate entirely on analog electronics without any digital processor or programming. */
            subject robot : PhotovoreRobot;
        }
        
        requirement <'REQ-3'> 'Charge Discharge Cycle' {
            doc /* The robot shall store energy in a capacitor and discharge it through motors when a voltage threshold is reached, producing jerky step-by-step movement. */
            subject robot : PhotovoreRobot;
        }
        
        requirement <'REQ-4'> 'Photovore Behavior' {
            doc /* The robot shall turn toward the brightest light source using independent left and right sensing and power generation circuits. */
            subject robot : PhotovoreRobot;
        }
        
        requirement <'REQ-5'> 'Solar Energy Harvesting' {
            doc /* The robot shall harvest energy from ambient light using solar cells. */
            subject robot : PhotovoreRobot;
        }
        
        satisfy 'Light to Motion Conversion' by robot;
        satisfy 'Autonomous Analog Operation' by robot;
        satisfy 'Charge Discharge Cycle' by robot;
        satisfy 'Photovore Behavior' by robot;
        satisfy 'Solar Energy Harvesting' by robot;
    }
}
