package PowerGenerationSystem {
    public import ISQ::*;
    public import ScalarValues::*;
    
    package Definitions {
        public import PartDefinitions::*;
        public import PortDefinitions::*;
        public import ItemDefinitions::*;
        public import RequirementDefinitions::*;
        
        package ItemDefinitions {
            private import ISQ::*;
            
            item def ThrottleCommand {
                attribute throttlePosition: Real;
                attribute timestamp: Real;
            }
            
            item def PowerMeasurement {
                attribute horsepowerOutput: ISQ::PowerValue;
                attribute torqueOutput: ISQ::TorqueValue;
                attribute rotationalSpeed: Real;
                attribute timestamp: Real;
            }
            
            item def PowerTarget {
                attribute targetHorsepower: ISQ::PowerValue;
            }
            
            item def MechanicalPower {
                attribute horsepower: ISQ::PowerValue;
                attribute torque: ISQ::TorqueValue;
                attribute rpm: Real;
            }
        }
        
        package PortDefinitions {
            port def ThrottleCommandPort {
                in item throttleCmd: ThrottleCommand;
            }
            
            port def PowerMonitorPort {
                out item powerData: PowerMeasurement;
            }
            
            port def PowerTargetPort {
                in item target: PowerTarget;
            }
            
            port def MechanicalOutputPort {
                out item mechanicalPower: MechanicalPower;
            }
            
            port def MechanicalInputPort {
                in item mechanicalPower: MechanicalPower;
            }
        }
        
        package PartDefinitions {
            private import ISQ::*;
            
            part def CombustionChamber {
                attribute volume: ISQ::VolumeValue;
                attribute temperature: ISQ::TemperatureValue;
                attribute pressure: ISQ::PressureValue;
                
                perform action combustFuel {
                    in fuelMass: ISQ::MassValue;
                    out thermalEnergy: ISQ::EnergyValue;
                }
            }
            
            part def Crankshaft {
                attribute angularVelocity: Real;
                attribute outputTorque: ISQ::TorqueValue;
                
                perform action convertReciprocatingToRotary {
                    in pistonForce: ISQ::ForceValue;
                    out rotationalPower: ISQ::PowerValue;
                }
            }
            
            part def Piston {
                attribute diameter: ISQ::LengthValue;
                attribute stroke: ISQ::LengthValue;
                attribute compressionRatio: Real;
                
                perform action compressAndExpand {
                    in combustionPressure: ISQ::PressureValue;
                    out linearForce: ISQ::ForceValue;
                }
            }
            
            part def FuelInjectionSystem {
                attribute fuelFlowRate: Real;
                attribute injectionPressure: ISQ::PressureValue;
                attribute injectionTiming: Real;
                
                perform action injectFuel {
                    in throttlePosition: Real;
                    out fuelMass: ISQ::MassValue;
                }
            }
            
            part def PowerPlant {
                attribute maxHorsepower: ISQ::PowerValue;
                attribute numberOfPistons: Integer;
                attribute currentPowerOutput: ISQ::PowerValue;
                attribute currentTorque: ISQ::TorqueValue;
                attribute engineSpeed: Real;
                attribute throttlePosition: Real;
                
                port throttlePort: ThrottleCommandPort;
                port monitorPort: PowerMonitorPort;
                port outputPort: MechanicalOutputPort;
                
                part combustionChambers: CombustionChamber[8];
                part crankshaft: Crankshaft[1];
                part pistons: Piston[8];
                part fuelInjection: FuelInjectionSystem[1];
                
                perform action generatePower {
                    action receiveThrottle accept ThrottleCommand via throttlePort;
                    then action injectFuelStep :> fuelInjection.injectFuel;
                    then action combustStep :> combustionChambers[1].combustFuel;
                    then action convertStep :> crankshaft.convertReciprocatingToRotary;
                }
                
                perform action monitorOutput {
                    action measurePower;
                    then action sendMeasurement send new PowerMeasurement() via monitorPort;
                }
                
                perform action deliverMechanicalPower {
                    action assemblePower;
                    then action transmitPower send new MechanicalPower() via outputPort;
                }
                
                perform action operatingBehavior {
                    action step1 :> generatePower;
                    then action step2 :> monitorOutput;
                    then action step3 :> deliverMechanicalPower;
                }
                
                exhibit state engineStates {
                    entry action initializeEngine;
                    
                    state shutdown {
                        entry action stopFuelFlow;
                    }
                    
                    state starting {
                        entry action engageStarter;
                        do action primeFuelSystem;
                    }
                    
                    state idle {
                        entry action setIdleThrottle;
                        do generatePower;
                    }
                    
                    state operating {
                        entry action enableFullThrottle;
                        do operatingBehavior;
                        
                        state low;
                        state medium;
                        state high;
                        
                        transition low_to_medium
                            first low
                            if currentPowerOutput >= 149140[W]
                            then medium;
                        
                        transition medium_to_high
                            first medium
                            if currentPowerOutput >= 298280[W]
                            then high;
                        
                        transition high_to_medium
                            first high
                            if currentPowerOutput < 298280[W]
                            then medium;
                        
                        transition medium_to_low
                            first medium
                            if currentPowerOutput < 149140[W]
                            then low;
                    }
                    
                    transition then shutdown;
                    
                    transition shutdown_to_starting
                        first shutdown
                        if throttlePosition > 0
                        then starting;
                    
                    transition starting_to_idle
                        first starting
                        if engineSpeed >= 500
                        then idle;
                    
                    transition idle_to_operating
                        first idle
                        if currentPowerOutput >= 37285[W]
                        then operating.low;
                    
                    transition operating_to_idle
                        first operating
                        if currentPowerOutput < 37285[W]
                        then idle;
                    
                    transition idle_to_shutdown
                        first idle
                        if throttlePosition == 0
                        then shutdown;
                }
            }
            
            part def PowerController {
                attribute targetPower: ISQ::PowerValue;
                attribute actualPower: ISQ::PowerValue;
                attribute powerError: ISQ::PowerValue;
                attribute controlGain: Real;
                attribute computedThrottle: Real;
                
                port targetPort: PowerTargetPort;
                port monitorPort: PowerMonitorPort;
                port commandPort: ThrottleCommandPort;
                
                perform action controlPower {
                    action receiveTarget accept PowerTarget via targetPort;
                    then action monitorActual accept PowerMeasurement via monitorPort;
                    then action calculateError;
                    then action calculateThrottle;
                    then action sendThrottleCommand send new ThrottleCommand() via commandPort;
                }
                
                exhibit state controllerStates {
                    state monitoring {
                        do controlPower;
                    }
                }
            }
            
            part def LoadDevice {
                attribute receivedPower: ISQ::PowerValue;
                attribute transferEfficiency: Real;
                attribute effectivePower: ISQ::PowerValue;
                
                port inputPort: MechanicalInputPort;
                
                perform action acceptPower {
                    action receiveMechanicalPower accept MechanicalPower via inputPort;
                    then action calculateEffectivePower;
                }
                
                exhibit state loadStates {
                    state receiving {
                        do acceptPower;
                    }
                }
            }
            
            part def PowerGenerationSystemAssembly {
                attribute systemEfficiency: Real;
                attribute targetOutputPower: ISQ::PowerValue;
                
                part engine: PowerPlant {
                    attribute :>> maxHorsepower = 372850[W];
                    attribute :>> numberOfPistons = 8;
                }
                
                part controller: PowerController {
                    attribute :>> controlGain = 0.8;
                }
                
                part load: LoadDevice {
                    attribute :>> transferEfficiency = 0.92;
                }
                
                connection controlToEngine 
                    connect controller.commandPort to engine.throttlePort;
                
                connection engineToController
                    connect engine.monitorPort to controller.monitorPort;
                
                connection engineToLoad
                    connect engine.outputPort to load.inputPort;
            }
        }
        
        package RequirementDefinitions {
            private import ISQ::*;
            
            requirement def PowerOutputRequirement {
                attribute requiredPower: ISQ::PowerValue;
            }
            
            requirement def PistonCountRequirement {
                attribute requiredPistons: Integer;
            }
            
            requirement def TransferEfficiencyRequirement {
                attribute minimumEfficiency: Real;
            }
        }
    }
    
    part powerSystem: Definitions::PartDefinitions::PowerGenerationSystemAssembly;
    
    requirement powerReq: Definitions::RequirementDefinitions::PowerOutputRequirement {
        attribute :>> requiredPower = 372850[W];
    }
    
    requirement pistonReq: Definitions::RequirementDefinitions::PistonCountRequirement {
        attribute :>> requiredPistons = 8;
    }
    
    requirement efficiencyReq: Definitions::RequirementDefinitions::TransferEfficiencyRequirement {
        attribute :>> minimumEfficiency = 0.90;
    }
}
