package ChernobylRBMK {
    package ValueTypes {
        value type PowerValue > Real { unit 'MW'; }
        value type ReactivityValue > Real { unit 'pcm'; }
        value type TemperatureValue > Real { unit 'K'; }
        value type PressureValue > Real { unit 'MPa'; }
        value type FlowRateValue > Real { unit 'kg/s'; }
        value type RodPositionValue > Real { unit 'm'; }
        value type VoidFractionValue > Real { unit 'percent'; }
        value type NeutronFluxValue > Real { unit 'n/cm2_s'; }
        value type TimeValue > Real { unit 's'; }
        value type ElectricalPowerValue > Real { unit 'MWe'; }
        value type MassValue > Real { unit 'kg'; }
    }

    package Items {
        item def Water;
        item def Steam;
        item def SteamWaterMixture;
        item def Graphite;
        item def UraniumDioxideFuel;
        item def BoronCarbide;
        item def Neutron;
        item def ControlSignal;
        item def ScramCommand;
        item def Electricity;
        item def FissionProduct;
        item def Hydrogen;
        item def Air;
    }

    package Requirements {
        requirement def ElectricityGenerationRequirement {
            doc /* The RBMK-1000 facility shall generate electricity through nuclear fission. */
            subject reactor : PowerValue;
            requirement { reactor >= 1000.0 [MW]; }
        }

        requirement def CoreConfigurationRequirement {
            doc /* The reactor core shall contain 1661 fuel channels and use a graphite moderator. */
            subject fuelChannelCount : Integer;
            subject moderator : Graphite;
            requirement { fuelChannelCount == 1661; }
        }

        requirement def PositiveVoidCoefficientRequirement {
            doc /* The reactor design exhibits a positive void coefficient: steam voids increase reactivity. */
            subject voidCoefficient : ReactivityValue;
            requirement { voidCoefficient > 0.0 [pcm]; }
        }

        requirement def ControlRodAssemblyRequirement {
            doc /* The control rod assembly shall consist of 211 rods with boron carbide absorbers and graphite displacer tips. */
            subject rodCount : Integer;
            requirement { rodCount == 211; }
        }

        requirement def EmergencyProtectionRequirement {
            doc /* The Emergency Protection System shall automatically initiate a reactor scram when unsafe conditions are detected. */
            subject epsTrigger : ControlSignal;
            requirement { epsTrigger.kind == 'scram'; }
        }

        requirement def SafetyTestScenarioRequirement {
            doc /* The model shall capture the fateful safety test sequence including unstable low-power operation, disabled safety systems, power surge, flawed rod insertion, and resulting explosions. */
        }
    }

    package Components {
        part def ReactorCore {
            attribute fuelChannelCount : Integer = 1661;
            attribute thermalPower : PowerValue;
            attribute reactivity : ReactivityValue;
            attribute coreTemperature : TemperatureValue;
            attribute voidFraction : VoidFractionValue;
            attribute voidCoefficient : ReactivityValue = 4.0 [pcm];
            attribute neutronFlux : NeutronFluxValue;
            
            port heatOut : ~SteamWaterMixture;
            port coolantIn : ~Water;
            port rodInterface : ~ControlSignal;
            port neutronFluxOut : ~NeutronFlux;
            
            item stores : Graphite[>>1];
            item fuel : UraniumDioxideFuel[>>1];
            
            exhibit state CoreBehavior {
                entry; then StableOperation;
                
                state StableOperation {
                    entry { thermalPower = 3200.0 [MW]; reactivity = 0.0 [pcm]; voidFraction = 0.0 [percent]; }
                }
                
                transition from StableOperation to LowPowerUnstable
                    when rodInterface.signal == 'power_reduction';
                
                state LowPowerUnstable {
                    entry { thermalPower = 30.0 [MW]; reactivity = -1000.0 [pcm]; voidFraction = 5.0 [percent]; }
                    do { voidFraction += 1.0 [percent]; reactivity += voidCoefficient * voidFraction; thermalPower += reactivity * 0.5 [MW/pcm]; }
                }
                
                transition from LowPowerUnstable to PowerSurge
                    when voidFraction > 20.0 [percent];
                
                state PowerSurge {
                    entry { reactivity = 500.0 [pcm]; }
                    do { thermalPower *= 2.0; voidFraction += 5.0 [percent]; }
                }
                
                transition from PowerSurge to RodInsertionSurge
                    when rodInterface.signal == 'scram';
                
                state RodInsertionSurge {
                    entry { reactivity = 3700.0 [pcm]; thermalPower = 50000.0 [MW]; }
                    do { coreTemperature = 4000.0 [K]; }
                }
                
                transition from RodInsertionSurge to SteamExplosion
                    when thermalPower > 40000.0 [MW];
                
                state SteamExplosion {
                    entry { coreTemperature = 5000.0 [K]; }
                }
                
                transition from SteamExplosion to GraphiteFire;
                
                state GraphiteFire {
                    entry { coreTemperature = 2000.0 [K]; }
                    do { emit FissionProduct; }
                }
            }
        }

        part def ControlRodAssembly {
            attribute rodCount : Integer = 211;
            attribute rodPosition : RodPositionValue;
            attribute absorberMaterial : BoronCarbide;
            attribute hasGraphiteDisplacerTip : Boolean = true;
            attribute insertionRate : Real = 0.4 [m/s];
            
            port commandIn : ~ControlSignal;
            port coreInterface : ~ControlSignal;
            
            exhibit state RodBehavior {
                entry; then Withdrawn;
                
                state Withdrawn {
                    entry { rodPosition = 7.0 [m]; }
                }
                
                transition from Withdrawn to Inserting
                    when commandIn.signal == 'scram';
                
                state Inserting {
                    entry { rodPosition -= insertionRate; }
                    do { coreInterface.send(ControlSignal{signal='graphite_tip_entering'}); }
                }
                
                transition from Inserting to PartiallyInserted
                    when rodPosition < 1.2 [m];
                
                state PartiallyInserted {
                    entry { coreInterface.send(ControlSignal{signal='reactivity_spike'}); }
                    do { rodPosition -= insertionRate; }
                }
                
                transition from PartiallyInserted to FullyInserted
                    when rodPosition <= 0.0 [m];
                
                state FullyInserted {
                    entry { rodPosition = 0.0 [m]; }
                }
            }
        }

        part def PrimaryCoolantCircuit {
            attribute coolantFlowRate : FlowRateValue;
            attribute coolantPressure : PressureValue;
            attribute coolantTemperature : TemperatureValue;
            attribute pumpStatus : String;
            
            port waterOut : ~Water;
            port mixtureIn : ~SteamWaterMixture;
            port separatorFeed : ~SteamWaterMixture;
            port coreFeed : ~Water;
            
            exhibit state CoolantBehavior {
                entry; then NormalFlow;
                
                state NormalFlow {
                    entry { coolantFlowRate = 37500.0 [kg/s]; coolantPressure = 7.0 [MPa]; pumpStatus = 'running'; }
                }
                
                transition from NormalFlow to ReducedFlow
                    when mixtureIn.flow < 10000.0 [kg/s];
                
                state ReducedFlow {
                    entry { coolantFlowRate = 5000.0 [kg/s]; pumpStatus = 'coasting_down'; }
                    do { coolantPressure -= 0.1 [MPa]; }
                }
                
                transition from ReducedFlow to FlowDisrupted
                    when coolantPressure < 1.0 [MPa];
                
                state FlowDisrupted {
                    entry { coolantFlowRate = 0.0 [kg/s]; pumpStatus = 'stopped'; }
                }
            }
        }

        part def SteamSeparatorDrum {
            attribute drumPressure : PressureValue;
            attribute waterLevel : Real;
            attribute steamQuality : Real;
            
            port mixtureIn : ~SteamWaterMixture;
            port steamOut : ~Steam;
            port waterOut : ~Water;
            
            exhibit state SeparatorBehavior {
                entry; then Separating;
                
                state Separating {
                    do { 
                        steamOut.send(Steam{pressure = drumPressure});
                        waterOut.send(Water{temperature = 543.0 [K]});
                    }
                }
                
                transition from Separating to Overpressurized
                    when drumPressure > 8.0 [MPa];
                
                state Overpressurized {
                    entry { drumPressure = 10.0 [MPa]; }
                }
                
                transition from Overpressurized to Ruptured
                    when drumPressure > 12.0 [MPa];
                
                state Ruptured {
                    entry { emit Steam; emit Water; }
                }
            }
        }

        part def TurbineGeneratorSet {
            attribute electricalOutput : ElectricalPowerValue;
            attribute rotorSpeed : Real;
            attribute turbineStatus : String;
            
            port steamIn : ~Steam;
            port electricityOut : ~Electricity;
            
            exhibit state TurbineBehavior {
                entry; then Generating;
                
                state Generating {
                    entry { electricalOutput = 925.0 [MWe]; rotorSpeed = 3000.0; turbineStatus = 'online'; }
                }
                
                transition from Generating to CoastDown
                    when steamIn.pressure < 5.0 [MPa];
                
                state CoastDown {
                    entry { electricalOutput = 0.0 [MWe]; rotorSpeed -= 50.0; turbineStatus = 'coasting'; }
                }
                
                transition from CoastDown to Stopped
                    when rotorSpeed <= 0.0;
                
                state Stopped {
                    entry { turbineStatus = 'stopped'; }
                }
            }
        }

        part def OperatorControlRoom {
            attribute reactorPowerReading : PowerValue;
            attribute voidFractionReading : VoidFractionValue;
            attribute safetySystemsEnabled : Boolean;
            attribute operatorAction : String;
            
            port coreStatusIn : ~NeutronFlux;
            port commandOut : ~ControlSignal;
            port epsOverride : ~ControlSignal;
            
            exhibit state OperatorBehavior {
                entry; then Monitoring;
                
                state Monitoring {
                    entry { safetySystemsEnabled = true; operatorAction = 'monitoring'; }
                }
                
                transition from Monitoring to ConductingSafetyTest
                    when reactorPowerReading < 100.0 [MW];
                
                state ConductingSafetyTest {
                    entry { safetySystemsEnabled = false; operatorAction = 'disabling_safety_systems'; }
                    do { epsOverride.send(ControlSignal{signal='disable_eps'}); }
                }
                
                transition from ConductingSafetyTest to InitiatingScram
                    when reactorPowerReading > 1000.0 [MW];
                
                state InitiatingScram {
                    entry { operatorAction = 'pressing_AZ5'; commandOut.send(ControlSignal{signal='scram'}); }
                }
                
                transition from InitiatingScram to EmergencyResponse;
                
                state EmergencyResponse {
                    entry { operatorAction = 'responding_to_explosion'; }
                }
            }
        }

        part def EmergencyProtectionSystem {
            attribute powerThreshold : PowerValue = 3300.0 [MW];
            attribute flowThreshold : FlowRateValue = 2000.0 [kg/s];
            attribute enabled : Boolean;
            attribute tripCondition : String;
            
            port sensorIn : ~NeutronFlux;
            port flowSensorIn : ~Water;
            port scramCommandOut : ~ScramCommand;
            port overrideIn : ~ControlSignal;
            
            exhibit state EPSBehavior {
                entry; then Armed;
                
                state Armed {
                    entry { enabled = true; tripCondition = 'monitoring'; }
                }
                
                transition from Armed to Disabled
                    when overrideIn.signal == 'disable_eps';
                
                state Disabled {
                    entry { enabled = false; tripCondition = 'overridden'; }
                }
                
                transition from Disabled to AttemptedScram
                    when sensorIn.flux > 1e14 [n/cm2_s];
                
                state AttemptedScram {
                    entry { scramCommandOut.send(ScramCommand{signal='scram'}); tripCondition = 'scram_initiated'; }
                }
                
                transition from AttemptedScram to Failed;
                
                state Failed {
                    entry { tripCondition = 'scram_failed'; }
                }
            }
        }
    }

    package System {
        part def ChernobylUnit4 {
            part reactorCore : Components::ReactorCore {
                attribute thermalPower = 3200.0 [MW];
            }
            part controlRods : Components::ControlRodAssembly;
            part coolantCircuit : Components::PrimaryCoolantCircuit;
            part steamSeparator : Components::SteamSeparatorDrum {
                attribute drumPressure = 6.9 [MPa];
            }
            part turbineGenerator : Components::TurbineGeneratorSet;
            part controlRoom : Components::OperatorControlRoom;
            part eps : Components::EmergencyProtectionSystem;
            
            connection coreToCoolant : reactorCore.heatOut to coolantCircuit.mixtureIn;
            connection coolantToSeparator : coolantCircuit.separatorFeed to steamSeparator.mixtureIn;
            connection separatorSteamToTurbine : steamSeparator.steamOut to turbineGenerator.steamIn;
            connection separatorWaterToCoolant : steamSeparator.waterOut to coolantCircuit.waterOut;
            connection coolantToCore : coolantCircuit.coreFeed to reactorCore.coolantIn;
            connection controlRoomToRods : controlRoom.commandOut to controlRods.commandIn;
            connection rodsToCore : controlRods.coreInterface to reactorCore.rodInterface;
            connection coreFluxToControlRoom : reactorCore.neutronFluxOut to controlRoom.coreStatusIn;
            connection coreFluxToEPS : reactorCore.neutronFluxOut to eps.sensorIn;
            connection coolantFlowToEPS : coolantCircuit.coreFeed to eps.flowSensorIn;
            connection controlRoomToEPS : controlRoom.epsOverride to eps.overrideIn;
            connection epsToRods : eps.scramCommandOut to controlRods.commandIn;
            
            satisfy Requirements::ElectricityGenerationRequirement by turbineGenerator.electricalOutput;
            satisfy Requirements::CoreConfigurationRequirement by reactorCore;
            satisfy Requirements::PositiveVoidCoefficientRequirement by reactorCore;
            satisfy Requirements::ControlRodAssemblyRequirement by controlRods;
            satisfy Requirements::EmergencyProtectionRequirement by eps;
            satisfy Requirements::SafetyTestScenarioRequirement by self;
        }
    }
}
