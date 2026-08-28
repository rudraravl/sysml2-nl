package 'Hydraulic Ram Pump System' {
    private import ISQ::VelocityValue;
    private import ISQ::PressureValue;
    
    item def Water {
        attribute velocity : VelocityValue;
        attribute pressure : PressureValue;
    }
    
    port def WaterOutPort {
        out item water : Water;
    }
    port def WaterInPort {
        in item water : Water;
    }
    
    part def WaterSource {
        port waterOut : WaterOutPort;
    }
    
    part def DrivePipe {
        port waterIn : WaterInPort;
        port waterOut : WaterOutPort;
        attribute flowVelocity : VelocityValue;
    }
    
    part def ImpulseValve {
        port waterIn : WaterInPort;
        port wasteOut : WaterOutPort;
        attribute internalPressure : PressureValue;
        attribute velocityThreshold : VelocityValue;
        attribute pressureThreshold : PressureValue;
    }
    
    part def CheckValve {
        port waterIn : WaterInPort;
        port waterOut : WaterOutPort;
    }
    
    part def AirChamber {
        port waterIn : WaterInPort;
        port waterOut : WaterOutPort;
        attribute airPressure : PressureValue;
    }
    
    part def DeliveryPipe {
        port waterIn : WaterInPort;
        port waterOut : WaterOutPort;
    }
    
    part def DeliveryReservoir {
        port waterIn : WaterInPort;
    }
    
    part def WasteSink {
        port waterIn : WaterInPort;
    }
    
    action def AccelerateWater {
        in waterIn : Water;
        out waterOut : Water;
    }
    
    action def SlamImpulseValve {
        in waterIn : Water;
        out waterOut : Water;
    }
    
    action def PressureSpike {
        in waterIn : Water;
        out waterOut : Water;
    }
    
    action def OpenCheckValve {
        in waterIn : Water;
        out waterOut : Water;
    }
    
    action def CompressAir {
        in waterIn : Water;
        out waterOut : Water;
    }
    
    action def DeliverWater {
        in waterIn : Water;
        out waterOut : Water;
    }
    
    action def ResetValves {
        in waterIn : Water;
        out waterOut : Water;
    }
    
    action def PumpingCycle {
        loop {
            action 'accelerate water' : AccelerateWater {
                in waterIn : Water;
                out waterOut : Water;
            }
            then action 'slam impulse valve' : SlamImpulseValve {
                in waterIn : Water;
                out waterOut : Water;
            }
            then action 'pressure spike' : PressureSpike {
                in waterIn : Water;
                out waterOut : Water;
            }
            then action 'open check valve' : OpenCheckValve {
                in waterIn : Water;
                out waterOut : Water;
            }
            then action 'compress air' : CompressAir {
                in waterIn : Water;
                out waterOut : Water;
            }
            then action 'deliver water' : DeliverWater {
                in waterIn : Water;
                out waterOut : Water;
            }
            then action 'reset valves' : ResetValves {
                in waterIn : Water;
                out waterOut : Water;
            }
        }
    }
    
    part def HydraulicRamPump {
        port waterIn : WaterInPort;
        port wasteOut : WaterOutPort;
        port deliveryOut : WaterOutPort;
        
        part drivePipe : DrivePipe;
        part impulseValve : ImpulseValve;
        part checkValve : CheckValve;
        part airChamber : AirChamber;
        part deliveryPipe : DeliveryPipe;
        
        flow of Water from waterIn.water to drivePipe.waterIn.water;
        flow of Water from drivePipe.waterOut.water to impulseValve.waterIn.water;
        flow of Water from drivePipe.waterOut.water to checkValve.waterIn.water;
        flow of Water from impulseValve.wasteOut.water to wasteOut.water;
        flow of Water from checkValve.waterOut.water to airChamber.waterIn.water;
        flow of Water from airChamber.waterOut.water to deliveryPipe.waterIn.water;
        flow of Water from deliveryPipe.waterOut.water to deliveryOut.water;
        
        perform action pumpingCycle : PumpingCycle;
    }
    
    part context {
        part source : WaterSource;
        part ramPump : HydraulicRamPump;
        part waste : WasteSink;
        part reservoir : DeliveryReservoir;
        
        flow of Water from source.waterOut.water to ramPump.waterIn.water;
        flow of Water from ramPump.wasteOut.water to waste.waterIn.water;
        flow of Water from ramPump.deliveryOut.water to reservoir.waterIn.water;
    }
    
    requirement def PumpWaterRequirement {
        subject pump : HydraulicRamPump;
        objective {
            doc "The pump shall lift water to a higher elevation using the water hammer effect without external power.";
        }
    }
    
    requirement pumpReq : PumpWaterRequirement {
        subject = context.ramPump;
    }
}
