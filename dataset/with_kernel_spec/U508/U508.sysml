package GerotorPumpSystem {
    private import SI::*;
    private import ISQ::*;
    private import ScalarValues::*;
    
    attribute def StartCmd;
    attribute def StopCmd;
    attribute def EmergencyCmd;
    attribute def ResetCmd;
    attribute def AtSpeedSignal;
    attribute def StoppedSignal;
    
    port def MechanicalPort {
        attribute torque :> ISQ::torque;
        attribute speed :> ISQ::angularVelocity;
    }
    
    port def HydraulicPort {
        attribute pressure :> ISQ::pressure;
        attribute flowRate :> ISQ::volumeFlowRate;
    }
    
    part def DriveShaft {
        attribute length :> ISQ::length;
        attribute diameter :> ISQ::length;
        port mechIn : MechanicalPort;
        port mechOut : MechanicalPort;
    }
    
    part def InnerRotor {
        attribute lobes : Integer = 6;
        attribute eccentricity :> ISQ::length;
        port mechIn : MechanicalPort;
        port mechOut : MechanicalPort;
    }
    
    part def OuterRotor {
        attribute cavities : Integer = 7;
        port mechIn : MechanicalPort;
    }
    
    part def Housing {
        attribute inletDiameter :> ISQ::length;
        attribute outletDiameter :> ISQ::length;
        port inlet : HydraulicPort;
        port outlet : HydraulicPort;
    }
    
    action def AccelerateShaft;
    action def DisplaceFluid;
    action def DecelerateShaft;
    
    state def PumpStates {
        entry; then stopped;
        state stopped;
        transition stopped_to_starting
            first stopped
            accept StartCmd
            then starting;
        state starting {
            do AccelerateShaft;
        }
        transition starting_to_operational
            first starting
            accept AtSpeedSignal
            then operational;
        state operational {
            do DisplaceFluid;
        }
        transition operational_to_stopping
            first operational
            accept StopCmd
            then stopping;
        state stopping {
            do DecelerateShaft;
        }
        transition stopping_to_stopped
            first stopping
            accept StoppedSignal
            then stopped;
        transition operational_to_emergency
            first operational
            accept EmergencyCmd
            then emergency;
        transition stopping_to_emergency
            first stopping
            accept EmergencyCmd
            then emergency;
        state emergency;
        transition emergency_to_stopped
            first emergency
            accept ResetCmd
            then stopped;
    }
    
    part def GerotorPump {
        attribute ratedFlowRate :> ISQ::volumeFlowRate;
        attribute maxOperatingPressure :> ISQ::pressure;
        attribute minVolumetricEfficiency : Real;
        attribute currentEfficiency : Real;
        attribute currentFlowRate :> ISQ::volumeFlowRate;
        attribute currentPressure :> ISQ::pressure;
        
        port mechIn : MechanicalPort;
        port hydIn : HydraulicPort;
        port hydOut : HydraulicPort;
        
        part driveShaft : DriveShaft;
        part innerRotor : InnerRotor;
        part outerRotor : OuterRotor;
        part housing : Housing;
        
        connect mechIn to driveShaft.mechIn;
        connect driveShaft.mechOut to innerRotor.mechIn;
        connect innerRotor.mechOut to outerRotor.mechIn;
        connect hydIn to housing.inlet;
        connect housing.outlet to hydOut;
        
        exhibit state pumpStates : PumpStates;
    }
    
    part gerotorPump : GerotorPump {
        attribute ratedFlowRate = 0.00025 [m^3/s];
        attribute maxOperatingPressure = 25000000 [Pa];
        attribute minVolumetricEfficiency = 0.85;
    }
    
    requirement def GerotorPumpRequirements {
        subject pump : GerotorPump;
        
        doc /* The pump must deliver at least the rated flow rate of 15 L/min. */
        require constraint { pump.currentFlowRate >= pump.ratedFlowRate }
        
        doc /* The pump must withstand the maximum operating pressure of 25 MPa. */
        require constraint { pump.currentPressure <= pump.maxOperatingPressure }
        
        doc /* The pump must maintain high volumetric efficiency of at least 85%. */
        require constraint { pump.currentEfficiency >= pump.minVolumetricEfficiency }
    }
    
    requirement gerotorPumpRequirements : GerotorPumpRequirements {
        subject pump = gerotorPump;
    }
}
