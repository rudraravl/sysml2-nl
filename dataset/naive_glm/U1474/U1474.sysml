package PharmaPlantModel {
    import ScalarValues::*;
    
    package Definitions {
        unit kg;
        unit degC;
        unit bar;
        unit LperMin;
        unit kN;
        unit min;
        unit rpm;
        unit um;
        unit N;
        
        value type Mass :> Real { unit kg; }
        value type Temperature :> Real { unit degC; }
        value type Pressure :> Real { unit bar; }
        value type FlowRate :> Real { unit LperMin; }
        value type Force :> Real { unit kN; }
        value type Duration :> Real { unit min; }
        value type Speed :> Real { unit rpm; }
        value type ParticleSize :> Real { unit um; }
        value type Hardness :> Real { unit N; }
        
        item def RawAPI;
        item def Excipient;
        item def Solvent;
        item def LiquidMixture;
        item def CrystalSlurry;
        item def WetCake;
        item def WasteSolvent;
        item def DryPowder;
        item def MilledPowder;
        item def Tablet;
        item def TabletSample;
        
        enum def QCStatus { Pass; Fail; Adjust; }
        
        item def ControlCommand {
            attr tempSetpoint : Temperature;
            attr pressureSetpoint : Pressure;
            attr speedSetpoint : Speed;
        }
        
        item def SensorReading {
            attr actualTemp : Temperature;
            attr actualPressure : Pressure;
            attr actualFlow : FlowRate;
            attr actualMass : Mass;
        }
        
        item def QCFeedback {
            attr status : QCStatus;
            attr potency : Real;
            attr weight : Mass;
            attr dissolutionTime : Duration;
        }
    }
    
    package Components {
        import Definitions::*;
        
        part def MixingVessel {
            port in apiIn : RawAPI;
            port in excipientIn : Excipient;
            port in solventIn : Solvent;
            port out mixtureOut : LiquidMixture;
            
            port in cmdIn : ControlCommand;
            port out dataOut : SensorReading;
            
            attr temp : Temperature;
            attr agitatorSpeed : Speed;
            attr batchComplete : Boolean = false;
            
            state machine mixingStates {
                state Idle;
                state Filling {
                    do { wait(10[min]); }
                }
                state Mixing {
                    do { wait(30[min]); }
                    entry { temp = 25.0; agitatorSpeed = 100.0; }
                }
                state Draining {
                    do { wait(15[min]); }
                }
                transition from Idle to Filling when !batchComplete;
                transition from Filling to Mixing;
                transition from Mixing to Draining;
                transition from Draining to Idle {
                    effect { batchComplete = true; }
                }
            }
        }
        
        part def Crystallizer {
            port in mixtureIn : LiquidMixture;
            port out slurryOut : CrystalSlurry;
            port in cmdIn : ControlCommand;
            port out dataOut : SensorReading;
            
            attr temp : Temperature;
            attr batchComplete : Boolean = false;
            
            state machine crystallizerStates {
                state Idle;
                state Receiving {
                    do { wait(10[min]); }
                }
                state Cooling {
                    do { wait(60[min]); }
                    entry { temp = 5.0; }
                }
                state Discharging {
                    do { wait(15[min]); }
                }
                transition from Idle to Receiving when !batchComplete;
                transition from Receiving to Cooling;
                transition from Cooling to Discharging;
                transition from Discharging to Idle {
                    effect { batchComplete = true; }
                }
            }
        }
        
        part def FilterPress {
            port in slurryIn : CrystalSlurry;
            port out wetCakeOut : WetCake;
            port out wasteOut : WasteSolvent;
            port in cmdIn : ControlCommand;
            port out dataOut : SensorReading;
            
            attr pressure : Pressure;
            attr batchComplete : Boolean = false;
            
            state machine filterStates {
                state Idle;
                state Filtering {
                    do { wait(20[min]); }
                    entry { pressure = 5.0; }
                }
                state Discharging {
                    do { wait(10[min]); }
                }
                transition from Idle to Filtering when !batchComplete;
                transition from Filtering to Discharging;
                transition from Discharging to Idle {
                    effect { batchComplete = true; }
                }
            }
        }
        
        part def FluidBedDryer {
            port in wetCakeIn : WetCake;
            port out dryPowderOut : DryPowder;
            port in cmdIn : ControlCommand;
            port out dataOut : SensorReading;
            
            attr temp : Temperature;
            attr airflow : FlowRate;
            attr batchComplete : Boolean = false;
            
            state machine dryingStates {
                state Idle;
                state Drying {
                    do { wait(45[min]); }
                    entry { temp = 40.0; airflow = 50.0; }
                }
                state Discharging {
                    do { wait(10[min]); }
                }
                transition from Idle to Drying when !batchComplete;
                transition from Drying to Discharging;
                transition from Discharging to Idle {
                    effect { batchComplete = true; }
                }
            }
        }
        
        part def Mill {
            port in dryPowderIn : DryPowder;
            port out milledPowderOut : MilledPowder;
            port in cmdIn : ControlCommand;
            port out dataOut : SensorReading;
            
            attr particleSize : ParticleSize;
            attr speed : Speed;
            attr batchComplete : Boolean = false;
            
            state machine millingStates {
                state Idle;
                state Milling {
                    do { wait(20[min]); }
                    entry { speed = 500.0; }
                }
                transition from Idle to Milling when !batchComplete;
                transition from Milling to Idle {
                    effect { batchComplete = true; }
                }
            }
        }
        
        part def TabletPress {
            port in milledPowderIn : MilledPowder;
            port out tabletOut : Tablet;
            port out sampleOut : TabletSample;
            port in cmdIn : ControlCommand;
            port out dataOut : SensorReading;
            
            attr compressionForce : Force;
            attr tabletWeight : Mass;
            attr tabletHardness : Hardness;
            attr batchComplete : Boolean = false;
            
            state machine pressStates {
                state Idle;
                state Compressing {
                    do { wait(30[min]); }
                    entry { compressionForce = 10.0; }
                }
                transition from Idle to Compressing when !batchComplete;
                transition from Compressing to Idle {
                    effect { batchComplete = true; }
                }
            }
        }
        
        part def ProcessAutomationSystem {
            port in sensorInMix : SensorReading;
            port in sensorInCryst : SensorReading;
            port in sensorInFilter : SensorReading;
            port in sensorInDryer : SensorReading;
            port in sensorInMill : SensorReading;
            port in sensorInPress : SensorReading;
            port in qcFeedbackIn : QCFeedback;
            
            port out cmdOutMix : ControlCommand;
            port out cmdOutCryst : ControlCommand;
            port out cmdOutFilter : ControlCommand;
            port out cmdOutDryer : ControlCommand;
            port out cmdOutMill : ControlCommand;
            port out cmdOutPress : ControlCommand;
            
            action monitorLoop {
                if (qcFeedbackIn.status == QCStatus::Adjust) {
                    cmdOutMix.tempSetpoint = 20.0;
                    cmdOutCryst.tempSetpoint = 5.0;
                    cmdOutMix.speedSetpoint = 80.0;
                }
                if (sensorInMix.actualTemp > 25.0) {
                    cmdOutMix.speedSetpoint = 50.0;
                }
                if (sensorInCryst.actualTemp < 0.0) {
                    cmdOutCryst.tempSetpoint = 10.0;
                }
            }
        }
        
        part def QualityControlLab {
            port in sampleIn : TabletSample;
            port out qcFeedbackOut : QCFeedback;
            
            action testTablet {
                attr measuredWeight : Mass = 100.0;
                attr measuredPotency : Real = 0.98;
                attr dissolutionTime : Duration = 25.0;
                
                qcFeedbackOut.weight = measuredWeight;
                qcFeedbackOut.potency = measuredPotency;
                qcFeedbackOut.dissolutionTime = dissolutionTime;
                
                if (measuredWeight < 100.0 || measuredPotency < 0.95 || dissolutionTime > 30.0) {
                    qcFeedbackOut.status = QCStatus::Adjust;
                } else {
                    qcFeedbackOut.status = QCStatus::Pass;
                }
            }
        }
        
        part def RawMaterialSource {
            port out apiOut : RawAPI;
            port out excipientOut : Excipient;
            port out solventOut : Solvent;
        }
        
        part def WasteSink {
            port in wasteIn : WasteSolvent;
        }
        
        part def TabletSink {
            port in tabletIn : Tablet;
        }
    }
    
    package Requirements {
        import Definitions::*;
        
        requirement def TabletQuality {
            subject tablet : Tablet;
            objective {
                weight : Mass = 100.0;
                hardness : Hardness = 50.0;
                dissolutionTime : Duration <= 30.0;
            }
        }
    }
    
    package System {
        import Components::*;
        import Requirements::*;
        
        part def PharmaPlant {
            part source : RawMaterialSource;
            part mixer : MixingVessel;
            part crystallizer : Crystallizer;
            part filter : FilterPress;
            part dryer : FluidBedDryer;
            part mill : Mill;
            part press : TabletPress;
            part waste : WasteSink;
            part tabletDest : TabletSink;
            part pas : ProcessAutomationSystem;
            part qc : QualityControlLab;
            
            requirement tabletQualityReq : TabletQuality {
                subject tablet = tabletDest.tabletIn;
            }
            
            connection apiFlow from source.apiOut to mixer.apiIn;
            connection excipientFlow from source.excipientOut to mixer.excipientIn;
            connection solventFlow from source.solventOut to mixer.solventIn;
            connection mixToCryst from mixer.mixtureOut to crystallizer.mixtureIn;
            connection crystToFilter from crystallizer.slurryOut to filter.slurryIn;
            connection filterToDryer from filter.wetCakeOut to dryer.wetCakeIn;
            connection filterToWaste from filter.wasteOut to waste.wasteIn;
            connection dryerToMill from dryer.dryPowderOut to mill.dryPowderIn;
            connection millToPress from mill.milledPowderOut to press.milledPowderIn;
            connection pressToTabletDest from press.tabletOut to tabletDest.tabletIn;
            connection pressToQC from press.sampleOut to qc.sampleIn;
            
            connection mixCmd from pas.cmdOutMix to mixer.cmdIn;
            connection crystCmd from pas.cmdOutCryst to crystallizer.cmdIn;
            connection filterCmd from pas.cmdOutFilter to filter.cmdIn;
            connection dryerCmd from pas.cmdOutDryer to dryer.cmdIn;
            connection millCmd from pas.cmdOutMill to mill.cmdIn;
            connection pressCmd from pas.cmdOutPress to press.cmdIn;
            
            connection mixData from mixer.dataOut to pas.sensorInMix;
            connection crystData from crystallizer.dataOut to pas.sensorInCryst;
            connection filterData from filter.dataOut to pas.sensorInFilter;
            connection dryerData from dryer.dataOut to pas.sensorInDryer;
            connection millData from mill.dataOut to pas.sensorInMill;
            connection pressData from press.dataOut to pas.sensorInPress;
            
            connection qcFeedback from qc.qcFeedbackOut to pas.qcFeedbackIn;
        }
    }
}
