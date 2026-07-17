package 'Suction System Model' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    attribute def VacuumPressure :> PressureValue;
    attribute def AirFlowRate :> VolumeFlowRateValue;
    attribute def MotorSpeed :> AngularVelocityValue;
    attribute def FilterLoad :> MassValue;
    attribute def ContainerLevel :> VolumeValue;

    item def Air;
    item def Debris;
    item def FilteredAir;
    item def ContaminatedAir;

    attribute def SystemOn;
    attribute def SystemOff;
    attribute def FilterClogged;
    attribute def ContainerFull;

    port def AirIntakePort {
        in item incomingAir : ContaminatedAir;
        in item debris : Debris[*];
        attribute intakePressure : VacuumPressure;
    }

    port def AirExhaustPort {
        out item exhaustAir : FilteredAir;
        attribute exhaustPressure : PressureValue;
    }

    port def PowerInputPort {
        in attribute powerSupply : PowerValue;
    }

    part def ElectricMotor {
        port powerIn : PowerInputPort;
        attribute ratedPower : PowerValue;
        attribute currentSpeed : MotorSpeed;
        attribute efficiency : Real;

        perform action driveImpeller {
            in power : PowerValue;
            out speed : MotorSpeed;
            out torque : TorqueValue;
        }
    }

    part def CentrifugalImpeller {
        attribute diameter : LengthValue;
        attribute bladeCount : Integer;
        attribute rotationSpeed : MotorSpeed;

        perform action generateAirflow {
            in speed : MotorSpeed;
            out vacuumPressure : VacuumPressure;
            out flowRate : AirFlowRate;
        }
    }

    part def CycloneSeparator {
        port airIn : AirIntakePort;
        attribute separationEfficiency : Real;
        attribute chamberDiameter : LengthValue;

        perform action separateDebris {
            in item contaminatedAir : ContaminatedAir;
            in item debrisParticles : Debris[*];
            out item separatedDebris : Debris[*];
            out item partiallyCleanedAir : Air;
        }
    }

    part def HEPAFilter {
        attribute filterArea : AreaValue;
        attribute efficiency : Real;
        attribute maxLoad : FilterLoad;
        attribute currentLoad : FilterLoad;

        state filterState {
            entry; then clean;

            state clean;
            accept when currentLoad < maxLoad * 0.6
                then partiallyLoaded;

            state partiallyLoaded;
            accept when currentLoad < maxLoad * 0.9
                then nearlyFull;
            accept when currentLoad < maxLoad * 0.6
                then clean;

            state nearlyFull;
            accept when currentLoad >= maxLoad
                then clogged;
            accept when currentLoad < maxLoad * 0.9
                then partiallyLoaded;

            state clogged;
        }

        perform action filterParticulates {
            in item inputAir : Air;
            out item outputAir : FilteredAir;
            out item capturedParticles : Debris[*];
        }
    }

    part def DebrisCollectionBin {
        attribute maxCapacity : ContainerLevel;
        attribute currentLevel : ContainerLevel;

        perform action storeDebris {
            in item collectedDebris : Debris[*];
        }
    }

    part def PressureSensor {
        attribute measuredPressure : VacuumPressure;

        perform action measureVacuum {
            out pressure : VacuumPressure;
        }
    }

    part def ControlUnit {
        attribute targetVacuum : VacuumPressure;

        perform action regulateOperation {
            in currentPressure : VacuumPressure;
            in filterStatus : Boolean;
            in binStatus : Boolean;
            out motorCommand : PowerValue;
        }
    }

    requirement def VacuumGenerationRequirement {
        doc /* The suction system shall generate a minimum vacuum pressure 
               of 18 kPa below ambient to ensure effective debris removal. */
        
        subject systemVacuum : VacuumPressure;
        
        require constraint {
            systemVacuum >= -18.0 [SI::kPa]
        }
    }

    requirement def AirflowCapacityRequirement {
        doc /* The system shall maintain a minimum airflow rate of 30 liters 
               per second during continuous operation. */
        
        subject systemFlowRate : AirFlowRate;
        
        require constraint {
            systemFlowRate >= 30.0 [SI::L/SI::s]
        }
    }

    requirement def FiltrationEfficiencyRequirement {
        doc /* The HEPA filter shall capture at least 99.97% of particles 
               0.3 micrometers or larger. */
        
        subject filterEff : Real;
        
        require constraint {
            filterEff >= 0.9997
        }
    }

    requirement def DebrisSeparationRequirement {
        doc /* The cyclone separator shall remove at least 95% of debris 
               particles before air reaches the filter. */
        
        subject separationEff : Real;
        
        require constraint {
            separationEff >= 0.95
        }
    }

    part def SuctionSystem {
        doc /* A suction system that creates negative pressure to draw in air 
               and debris, separates solid contaminants through cyclonic action, 
               filters remaining particulates, and exhausts clean air while 
               collecting debris in a removable container. */

        port intakePort : AirIntakePort;
        port exhaustPort : AirExhaustPort;
        port powerPort : PowerInputPort;

        part motor : ElectricMotor {
            :>> ratedPower = 1200.0 [SI::W];
            :>> efficiency = 0.85;
        }

        part impeller : CentrifugalImpeller {
            :>> diameter = 0.12 [SI::m];
            :>> bladeCount = 8;
        }

        part cyclone : CycloneSeparator {
            :>> separationEfficiency = 0.96;
            :>> chamberDiameter = 0.15 [SI::m];
        }

        part hepaFilter : HEPAFilter {
            :>> filterArea = 0.25 [SI::m^2];
            :>> efficiency = 0.9997;
            :>> maxLoad = 0.5 [SI::kg];
            :>> currentLoad = 0.0 [SI::kg];
        }

        part debrisBin : DebrisCollectionBin {
            :>> maxCapacity = 2.0 [SI::L];
            :>> currentLevel = 0.0 [SI::L];
        }

        part pressureSensor : PressureSensor;

        part controller : ControlUnit {
            :>> targetVacuum = -20.0 [SI::kPa];
        }

        connection motorToImpeller connect motor to impeller;
        connection impellerToCyclone connect impeller to cyclone;
        connection cycloneToFilter connect cyclone to hepaFilter;
        connection filterToExhaust connect hepaFilter to exhaustPort;
        connection cycloneToBin connect cyclone to debrisBin;
        connection sensorToController connect pressureSensor to controller;
        connection controllerToMotor connect controller to motor;

        attribute systemVacuum : VacuumPressure;
        attribute systemFlowRate : AirFlowRate;
        attribute operatingPower : PowerValue;

        perform action operateSuctionSystem {
            first start;

            then action initializeSystem {
                send powerPort.powerSupply to motor.driveImpeller;
            }

            then action activateMotor {
                action motorDrive : motor.driveImpeller {
                    in power = powerPort.powerSupply;
                    out speed;
                    out torque;
                }
                flow motorDrive.speed to impellerGen.speed;
            }

            then action generateVacuum {
                action impellerGen : impeller.generateAirflow {
                    in speed;
                    out vacuumPressure;
                    out flowRate;
                }
            }
            then assign systemVacuum := generateVacuum.impellerGen.vacuumPressure;
            then assign systemFlowRate := generateVacuum.impellerGen.flowRate;

            then merge operationLoop;

            then action monitorAndControl {
                action sensorRead : pressureSensor.measureVacuum {
                    out pressure;
                }
                action controlReg : controller.regulateOperation {
                    in currentPressure = sensorRead.pressure;
                    in filterStatus = hepaFilter.filterState == hepaFilter.filterState::clogged;
                    in binStatus = debrisBin.currentLevel >= debrisBin.maxCapacity;
                    out motorCommand;
                }
            }

            then decide;
                if monitorAndControl.controlReg.filterStatus then handleFilterClogged;
                if monitorAndControl.controlReg.binStatus then handleBinFull;
                else processAirflow;

            action processAirflow {
                accept via intakePort;
                action cycloneSep : cyclone.separateDebris {
                    in item contaminatedAir;
                    in item debrisParticles[*];
                    out item separatedDebris[*];
                    out item partiallyCleanedAir;
                }
                flow cycloneSep.separatedDebris to binStore.collectedDebris;
                flow cycloneSep.partiallyCleanedAir to hepaFilt.inputAir;
                
                action binStore : debrisBin.storeDebris {
                    in item collectedDebris[*];
                }
                
                action hepaFilt : hepaFilter.filterParticulates {
                    in item inputAir;
                    out item outputAir;
                    out item capturedParticles[*];
                }
                flow hepaFilt.outputAir to exhaustPort;
            }
            then operationLoop;

            action handleFilterClogged {
                accept filterClogged : FilterClogged;
            }
            then done;

            action handleBinFull {
                accept containerFull : ContainerFull;
            }
            then done;
        }

        satisfy VacuumGenerationRequirement by operateSuctionSystem.generateVacuum;
        satisfy AirflowCapacityRequirement by operateSuctionSystem.generateVacuum;
        satisfy FiltrationEfficiencyRequirement by operateSuctionSystem.processAirflow;
        satisfy DebrisSeparationRequirement by operateSuctionSystem.processAirflow;
    }

    part industrialSuctionUnit : SuctionSystem {
        part motor {
            :>> ratedPower = 1500.0 [SI::W];
        }
        part cyclone {
            :>> chamberDiameter = 0.18 [SI::m];
        }
        part debrisBin {
            :>> maxCapacity = 3.0 [SI::L];
            :>> currentLevel = 0.5 [SI::L];
        }
    }
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import 'Suction System Model'::*;

    part testSubject : SuctionSystem {
    // TODO(human): unsupported input type for power: unknown (missing declared type)
    }
}
