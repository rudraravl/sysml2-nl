package DentalHandpieceSystem {
    import ISQ::*; 
    import ScalarValues::*;

    // ===== Value Types =====
    value def Pressure :> Real { unit 'Pa'; }
    value def FlowRate :> Real { unit 'm3/s'; }
    value def RotationalSpeed :> Real { unit 'rev/min'; }
    value def AngularVelocity :> Real { unit 'rad/s'; }
    value def Torque :> Real { unit 'N.m'; }
    value def Temperature :> Real { unit 'K'; }
    value def Volume :> Real { unit 'm3'; }
    value def MassFlowRate :> Real { unit 'kg/s'; }
    value def Force :> Real { unit 'N'; }
    value def Dimensionless :> Real { unit '1'; }
    value def Duration :> Real { unit 's'; }

    attribute maxTurbineSpeed : RotationalSpeed = 400000 [rev/min];
    attribute coolingActivationThreshold : RotationalSpeed = 50000 [rev/min];
    attribute minWaterPressure : Pressure = 100000 [Pa];
    attribute shutdownTimeout : Duration = 2.0 [s];

    // ===== Item Types =====
    item def CompressedAir;
    item def CoolingWater;
    item def ControlSignal;
    item def PedalPosition :> Dimensionless; // 0.0 to 1.0
    item def SpeedCommand :> RotationalSpeed;
    item def WaterCommand :> FlowRate;

    // ===== Port Definitions =====
    port def AirInPort {
        in air : CompressedAir;
        in pressure : Pressure;
        in flow : FlowRate;
    }

    port def AirOutPort {
        out air : CompressedAir;
        out pressure : Pressure;
        out flow : FlowRate;
    }

    port def WaterInPort {
        in water : CoolingWater;
        in pressure : Pressure;
        in flow : FlowRate;
    }

    port def WaterOutPort {
        out water : CoolingWater;
        out flow : FlowRate;
    }

    port def MechanicalPowerPort {
        out torque : Torque;
        out speed : RotationalSpeed;
    }

    port def ControlPort {
        in pedalPos : PedalPosition;
        out speedCmd : SpeedCommand;
        out waterCmd : WaterCommand;
    }

    port def SignalPort {
        out signal : ControlSignal;
    }

    port def WaterStatusPort {
        out pressure : Pressure;
        out sufficient : Boolean;
    }

    // ===== Requirements =====
    requirement def HandpieceRequirements {
        requirement SpeedCapability {
            doc /* The turbine shall achieve rotational speeds up to 400,000 RPM. */
            constraint { self.maxSpeed <= 400000 [rev/min] }
        }
        requirement SpeedControl {
            doc /* The turbine speed shall be proportional to foot pedal depression. */
            constraint { self.pedalPosition >= 0.0 and self.pedalPosition <= 1.0 }
        }
        requirement CoolingActivation {
            doc /* Cooling water shall activate when speed exceeds threshold. */
            constraint { self.speed > 50000 [rev/min] implies self.coolingActive == true }
        }
        requirement SafetyInterlock {
            doc /* Operation shall be prevented if water supply is insufficient. */
            constraint { self.waterSufficient == false implies self.operationEnabled == false }
        }
        requirement ShutdownSequence {
            doc /* The system shall stop rotation within 2 seconds of pedal release. */
            constraint { self.shutdownDuration <= 2.0 [s] }
        }
    }

    // ===== Parts =====
    part def FootPedal {
        attribute position : PedalPosition = 0.0;
        port out pedalOut : ControlPort;
        
        action def depressPedal :> Action {
            in depth : PedalPosition;
            then assign position := depth;
            then send pedalOut.pedalPos := position;
        }
        
        action def releasePedal :> Action {
            then assign position := 0.0;
            then send pedalOut.pedalPos := 0.0;
        }
    }

    part def AirTurbine {
        attribute currentSpeed : RotationalSpeed = 0 [rev/min];
        attribute outputTorque : Torque = 0 [N.m];
        port in airIn : AirInPort;
        port out mechOut : MechanicalPowerPort;
        
        action def spin :> Action {
            in airPressure : Pressure;
            in airFlow : FlowRate;
            then assign currentSpeed := (airFlow / 1e-6 [m3/s]) * 40000 [rev/min];
            then assign outputTorque := airPressure * 1e-6 [N.m/Pa];
            then send mechOut.speed := currentSpeed;
            then send mechOut.torque := outputTorque;
        }
    }

    part def BearingAssembly {
        attribute frictionCoefficient : Dimensionless = 0.001;
        port in mechIn : MechanicalPowerPort;
        port out mechOut : MechanicalPowerPort;
        
        action def transmitRotation :> Action {
            in inputSpeed : RotationalSpeed;
            in inputTorque : Torque;
            then assign mechOut.speed := inputSpeed * (1.0 - frictionCoefficient);
            then assign mechOut.torque := inputTorque * (1.0 - frictionCoefficient);
        }
    }

    part def BurrChuck {
        attribute clamped : Boolean = false;
        attribute burrDiameter : Real = 1.6 [mm];
        port in mechIn : MechanicalPowerPort;
        port out mechOut : MechanicalPowerPort;
        
        action def clampBurr :> Action {
            then assign clamped := true;
        }
        
        action def releaseBurr :> Action {
            then assign clamped := false;
        }
        
        action def transmitRotation :> Action {
            in inputSpeed : RotationalSpeed;
            in inputTorque : Torque;
            then assign mechOut.speed := inputSpeed;
            then assign mechOut.torque := inputTorque;
        }
    }

    part def Burr {
        attribute diameter : Real = 1.6 [mm];
        attribute cuttingEfficiency : Dimensionless = 0.95;
        port in mechIn : MechanicalPowerPort;
    }

    part def WaterDeliverySystem {
        attribute active : Boolean = false;
        attribute outputFlow : FlowRate = 0 [m3/s];
        attribute reservoirLevel : Volume = 0.001 [m3];
        attribute waterPressure : Pressure = 200000 [Pa];
        port in waterIn : WaterInPort;
        port out waterOut : WaterOutPort;
        port out statusOut : WaterStatusPort;
        
        action def activateCooling :> Action {
            in commandFlow : FlowRate;
            then assign active := true;
            then assign outputFlow := commandFlow;
            then send waterOut.flow := outputFlow;
            then send statusOut.pressure := waterPressure;
            then send statusOut.sufficient := (waterPressure >= minWaterPressure);
        }
        
        action def deactivateCooling :> Action {
            then assign active := false;
            then assign outputFlow := 0 [m3/s];
            then send waterOut.flow := 0 [m3/s];
        }
    }

    part def AirSupply {
        attribute tankPressure : Pressure = 300000 [Pa];
        attribute maxFlow : FlowRate = 0.005 [m3/s];
        port out airOut : AirOutPort;
        
        action def supplyAir :> Action {
            in commandedFlow : FlowRate;
            then assign airOut.flow := commandedFlow;
            then assign airOut.pressure := tankPressure;
        }
    }

    part def WaterSupply {
        attribute pressure : Pressure = 250000 [Pa];
        port out waterOut : WaterInPort;
        
        action def supplyWater :> Action {
            then assign waterOut.pressure := pressure;
            then assign waterOut.flow := 0.0001 [m3/s];
        }
    }

    part def ControlModule {
        attribute operationEnabled : Boolean = false;
        attribute coolingActive : Boolean = false;
        attribute targetSpeed : RotationalSpeed = 0 [rev/min];
        attribute waterCommandFlow : FlowRate = 0 [m3/s];
        attribute waterSufficient : Boolean = true;
        
        port in pedalIn : ControlPort;
        port in waterStatusIn : WaterStatusPort;
        port out airCommandOut : SignalPort;
        port out waterCommandOut : SignalPort;
        
        action def interpretPedal :> Action {
            in pedalPos : PedalPosition;
            in waterOk : Boolean;
            then assign waterSufficient := waterOk;
            then if (waterSufficient == true) {
                assign operationEnabled := true;
                assign targetSpeed := pedalPos * maxTurbineSpeed;
                assign airCommandOut.signal := ControlSignal { command = "supplyAir"; value = targetSpeed; };
                if (targetSpeed > coolingActivationThreshold) {
                    assign coolingActive := true;
                    assign waterCommandFlow := 0.00005 [m3/s];
                    assign waterCommandOut.signal := ControlSignal { command = "activateWater"; value = waterCommandFlow; };
                } else {
                    assign coolingActive := false;
                    assign waterCommandFlow := 0 [m3/s];
                    assign waterCommandOut.signal := ControlSignal { command = "deactivateWater"; value = 0 [m3/s]; };
                }
            } else {
                assign operationEnabled := false;
                assign targetSpeed := 0 [rev/min];
                assign airCommandOut.signal := ControlSignal { command = "stopAir"; value = 0 [rev/min]; };
                assign waterCommandOut.signal := ControlSignal { command = "deactivateWater"; value = 0 [m3/s]; };
            }
        }
        
        state def ControlBehavior {
            entry; then standby;
            
            state standby {
                entry then assign operationEnabled := false;
                entry then assign targetSpeed := 0 [rev/min];
                entry then assign coolingActive := false;
            }
            
            state operating {
                entry then assign operationEnabled := true;
                do interpretPedal;
            }
            
            state shutdown {
                entry then assign operationEnabled := false;
                entry then assign targetSpeed := 0 [rev/min];
                entry then assign coolingActive := false;
                exit;
            }
            
            transition from standby to operating when (pedalIn.pedalPos > 0.0 and waterStatusIn.sufficient == true);
            transition from operating to shutdown when (pedalIn.pedalPos == 0.0);
            transition from shutdown to standby after shutdownTimeout;
            transition from operating to standby when (waterStatusIn.sufficient == false);
        }
    }

    // ===== Top-level System =====
    part def DentalHandpiece {
        attribute maxSpeed : RotationalSpeed = maxTurbineSpeed;
        attribute coolingActive : Boolean = false;
        attribute waterSufficient : Boolean = true;
        attribute operationEnabled : Boolean = false;
        attribute shutdownDuration : Duration = 0 [s];
        
        part footPedal : FootPedal;
        part controlModule : ControlModule;
        part airSupply : AirSupply;
        part airTurbine : AirTurbine;
        part bearingAssembly : BearingAssembly;
        part burrChuck : BurrChuck;
        part burr : Burr;
        part waterSupply : WaterSupply;
        part waterDelivery : WaterDeliverySystem;
        
        // Connections
        connection footPedal.pedalOut to controlModule.pedalIn;
        connection waterDelivery.statusOut to controlModule.waterStatusIn;
        connection controlModule.airCommandOut to airSupply.airOut;
        connection airSupply.airOut to airTurbine.airIn;
        connection airTurbine.mechOut to bearingAssembly.mechIn;
        connection bearingAssembly.mechOut to burrChuck.mechIn;
        connection burrChuck.mechOut to burr.mechIn;
        connection waterSupply.waterOut to waterDelivery.waterIn;
        connection controlModule.waterCommandOut to waterDelivery.waterOut;
        
        // System-level state machine
        state def SystemOperation {
            entry; then standby;
            
            state standby {
                doc /* Idle state, no rotation, no cooling. */
                entry then assign operationEnabled := false;
            }
            
            state operating {
                doc /* Active cutting state, turbine spinning, cooling as needed. */
                entry then assign operationEnabled := true;
            }
            
            state shutdown {
                doc /* Safe stop sequence after pedal release. */
                entry then assign operationEnabled := false;
                entry then assign coolingActive := false;
            }
            
            transition from standby to operating 
                when (footPedal.position > 0.0 and waterDelivery.waterPressure >= minWaterPressure);
            transition from operating to shutdown 
                when (footPedal.position == 0.0);
            transition from shutdown to standby 
                after shutdownTimeout;
            transition from operating to standby 
                when (waterDelivery.waterPressure < minWaterPressure);
        }
        
        satisfy HandpieceRequirements {
            attribute maxSpeed = self.maxSpeed;
            attribute pedalPosition = self.footPedal.position;
            attribute speed = self.airTurbine.currentSpeed;
            attribute coolingActive = self.coolingActive;
            attribute waterSufficient = self.waterSufficient;
            attribute operationEnabled = self.operationEnabled;
            attribute shutdownDuration = self.shutdownDuration;
        }
    }
}
