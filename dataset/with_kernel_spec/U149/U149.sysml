package AutomatedAspiratorSystem {
    private import ScalarValues::Real;
    private import SI::*;
    private import ISQ::*;
    
    item def MotiveFluid;
    item def SuctionFluid;
    item def MixedFluid;
    item def StartCommand;
    item def StopCommand;
    item def EmergencySignal;
    item def ResetSignal;
    item def PressureStable;
    item def ShutdownComplete;
    
    attribute def PressureValue :> Real;
    attribute def ValvePositionValue :> Real;
    
    port def MotiveFluidOutPort {
        out motiveFluid : MotiveFluid;
    }
    port def MotiveFluidInPort {
        in motiveFluid : MotiveFluid;
    }
    port def SuctionFluidOutPort {
        out suctionFluid : SuctionFluid;
    }
    port def SuctionFluidInPort {
        in suctionFluid : SuctionFluid;
    }
    port def MixedFluidOutPort {
        out mixedFluid : MixedFluid;
    }
    port def MixedFluidInPort {
        in mixedFluid : MixedFluid;
    }
    port def PressureOutPort {
        out pressure : PressureValue;
    }
    port def PressureInPort {
        in pressure : PressureValue;
    }
    port def ValveControlInPort {
        in position : ValvePositionValue;
    }
    port def ValveControlOutPort {
        out position : ValvePositionValue;
    }
    
    part def MotiveFluidSource {
        port motiveOut : MotiveFluidOutPort;
    }
    
    part def FlowRegulationValve {
        port motiveIn : MotiveFluidInPort;
        port motiveOut : MotiveFluidOutPort;
        port controlIn : ValveControlInPort;
    }
    
    part def SuctionChamber {
        port suctionIn : SuctionFluidInPort;
        port suctionOut : SuctionFluidOutPort;
        port pressureOut : PressureOutPort;
    }
    
    part def DischargeChamber {
        port dischargeIn : MixedFluidInPort;
        port dischargeOut : MixedFluidOutPort;
    }
    
    part def VenturiTube {
        port motiveIn : MotiveFluidInPort;
        port suctionIn : SuctionFluidInPort;
        port dischargeOut : MixedFluidOutPort;
    }
    
    part def VacuumSensor {
        port pressureIn : PressureInPort;
        port pressureOut : PressureOutPort;
    }
    
    part def AspiratorController {
        port pressureIn : PressureInPort;
        port valveControlOut : ValveControlOutPort;
        attribute targetVacuum : PressureValue;
        
        state def AspiratorStateMachine {
            state idle;
            state startup;
            state normalOperation;
            state controlledShutdown;
            state emergencyStop;
            
            transition first idle accept startCmd : StartCommand then startup;
            transition first startup accept pressureStable : PressureStable then normalOperation;
            transition first normalOperation accept stopCmd : StopCommand then controlledShutdown;
            transition first controlledShutdown accept shutdownComplete : ShutdownComplete then idle;
            
            transition first idle accept emergencyTrigger : EmergencySignal then emergencyStop;
            transition first startup accept emergencyTrigger : EmergencySignal then emergencyStop;
            transition first normalOperation accept emergencyTrigger : EmergencySignal then emergencyStop;
            transition first controlledShutdown accept emergencyTrigger : EmergencySignal then emergencyStop;
            transition first emergencyStop accept resetCmd : ResetSignal then idle;
        }
        
        state : AspiratorStateMachine;
    }
    
    part aspiratorSystem {
        part motiveSource : MotiveFluidSource;
        part valve : FlowRegulationValve;
        part venturi : VenturiTube;
        part suctionChamber : SuctionChamber;
        part dischargeChamber : DischargeChamber;
        part sensor : VacuumSensor;
        part controller : AspiratorController;
        
        flow motiveFlow1 of MotiveFluid 
            from motiveSource.motiveOut.motiveFluid to valve.motiveIn.motiveFluid;
        flow motiveFlow2 of MotiveFluid 
            from valve.motiveOut.motiveFluid to venturi.motiveIn.motiveFluid;
        flow suctionFlow of SuctionFluid 
            from suctionChamber.suctionOut.suctionFluid to venturi.suctionIn.suctionFluid;
        flow dischargeFlow of MixedFluid 
            from venturi.dischargeOut.mixedFluid to dischargeChamber.dischargeIn.mixedFluid;
        flow pressureSignal1 of PressureValue 
            from suctionChamber.pressureOut.pressure to sensor.pressureIn.pressure;
        flow pressureFeedback of PressureValue 
            from sensor.pressureOut.pressure to controller.pressureIn.pressure;
        flow valveControlSignal of ValvePositionValue 
            from controller.valveControlOut.position to valve.controlIn.position;
    }
    
    requirement def VacuumControlRequirement {
        doc /* The system shall maintain the vacuum level in the suction chamber within 5% of the target vacuum setpoint. */
    }
    
    requirement def EmergencyStopRequirement {
        doc /* The system shall support an immediate emergency stop state that halts motive fluid flow and can be triggered at any time during operation. */
    }
    
    requirement def ClosedLoopControlRequirement {
        doc /* The aspirator controller shall continuously compare actual vacuum pressure against a target setpoint and adjust the flow regulation valve accordingly. */
    }
}
