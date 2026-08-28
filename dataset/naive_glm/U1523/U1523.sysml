package AutomatedWaterAerationSystem {
    import ScalarValues::*;
    
    value type MassFraction {
        unit mg_per_L;
    }
    unit mg_per_L {
        definition "milligrams per liter";
    }
    
    value type RotationalSpeed {
        unit rpm;
    }
    unit rpm {
        definition "revolutions per minute";
    }
    
    value type Volume {
        unit cubic_m;
    }
    unit cubic_m {
        definition "cubic meters";
    }
    
    enum ControlCommand {
        Off;
        On;
        Increase;
        Decrease;
    }
    
    item def Water {
        attribute dissolvedOxygen : MassFraction;
    }
    item def Air;
    
    port def WaterInPort {
        in item water : Water;
    }
    port def WaterOutPort {
        out item water : Water;
    }
    port def AirInPort {
        in item air : Air;
    }
    port def AirOutPort {
        out item air : Air;
    }
    port def DOPort {
        out reading : MassFraction;
    }
    port def CommandPort {
        out command : ControlCommand;
    }
    
    part def AerationChamber {
        port inlet : WaterInPort;
        port outlet : WaterOutPort;
        port airIn : AirInPort;
        
        attribute volume : Volume;
    }
    
    part def AirBlower {
        port airIntake : AirInPort;
        port airOut : AirOutPort;
        port commandIn : CommandPort;
        
        attribute currentSpeed : RotationalSpeed;
    }
    
    part def DiffuserGrid {
        port airIn : AirInPort;
        port airOut : AirOutPort;
    }
    
    part def DissolvedOxygenSensor {
        port waterIn : WaterInPort;
        port readingOut : DOPort;
    }
    
    part def AerationController {
        port sensorIn : DOPort;
        port commandOut : CommandPort;
        
        attribute setpoint : MassFraction;
        
        state machine Behavior {
            state Monitoring;
            state IncreasingSpeed {
                entry action send Increase on commandOut;
            }
            state DecreasingSpeed {
                entry action send Decrease on commandOut;
            }
            state Standby {
                entry action send Off on commandOut;
            }
            
            transition from Standby to Monitoring when sensorIn.reading > 0;
            transition from Monitoring to IncreasingSpeed when sensorIn.reading < setpoint;
            transition from Monitoring to DecreasingSpeed when sensorIn.reading > setpoint;
            transition from IncreasingSpeed to Monitoring when sensorIn.reading >= setpoint;
            transition from DecreasingSpeed to Monitoring when sensorIn.reading <= setpoint;
        }
    }
    
    part def AerationSystem {
        part chamber : AerationChamber;
        part blower : AirBlower;
        part diffuser : DiffuserGrid;
        part sensor : DissolvedOxygenSensor;
        part controller : AerationController;
        
        connection waterOutFlow connect chamber.outlet to sensor.waterIn;
        connection airToDiffuser connect blower.airOut to diffuser.airIn;
        connection diffuserToChamber connect diffuser.airOut to chamber.airIn;
        connection sensorToController connect sensor.readingOut to controller.sensorIn;
        connection controllerToBlower connect controller.commandOut to blower.commandIn;
    }
    
    requirement def MaintainDissolvedOxygen {
        subject system : AerationSystem;
        attribute targetDO : MassFraction;
        objective {
            doc "The system shall maintain the dissolved oxygen level in the chamber at or above the targetDO.";
            assert system.sensor.readingOut.reading >= targetDO;
        }
    }
}
