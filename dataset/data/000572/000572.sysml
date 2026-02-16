package ConvatecOstomyCareSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def DeviceID;
    attribute def PatientID;
    attribute def WearDuration :> TimeValue;
    
    attribute def EffluentVolume :> VolumeValue;
    
    attribute def AdhesionForce :> ForceValue;
    
    attribute def SkinpH :> Real;
    
    attribute def OdorReductionEfficiency :> Real;
    
    enum def SystemState {
        unattached;
        attached;
        collecting;
        nearCapacity;
        requiresChange;
        compromised;
    }
    
    enum def AlertType {
        none;
        leakageDetected;
        capacityWarning;
        adhesionFailure;
        wearTimeExpired;
        filterSaturated;
    }
    
    attribute def BarrierApplied;
    attribute def PouchAttached;
    attribute def PouchEmptied;
    attribute def SystemRemoved;
    
    item def Effluent {
        attribute volume: EffluentVolume;
        attribute consistency: String;
        attribute composition: String;
    }
    
    item def OdorousGas {
        attribute concentration: Real;
    }
    
    item def FilteredAir {
        attribute odorLevel: Real;
    }
    
    port def StomaInterface {
        in effluent: Effluent;
        in gas: OdorousGas;
    }
    
    port def SkinInterface {
        out adhesionForce: AdhesionForce;
        in skinpH: SkinpH;
        out protectionActive: Boolean;
    }
    
    port def PouchInterface {
        in effluent: Effluent;
        out currentVolume: EffluentVolume;
        out sealIntegrity: Boolean;
    }
    
    port def FilterInterface {
        in gas: OdorousGas;
        out filteredAir: FilteredAir;
    }
    
    part def SkinBarrier {
        attribute adhesionStrength: AdhesionForce;
        attribute integrityLevel: Real;
        attribute wearTime: WearDuration;
        attribute hydrocoloidActive: Boolean;
        
        port stomaPort: StomaInterface;
        port skinPort: SkinInterface;
        port pouchPort: PouchInterface;
        
        action maintainAdhesion {
            in skinCondition: SkinpH;
            in currentWearTime: WearDuration;
            out adhesionStatus: Real;
        }
        
        action protectSkin {
            in effluentExposure: Boolean;
            in skinpH: SkinpH;
            out protectionLevel: Real;
        }
    }
    
    part def CollectionPouch {
        attribute maxCapacity: EffluentVolume;
        attribute currentVolume: EffluentVolume;
        attribute material: String;
        attribute opaque: Boolean;
        
        port barrierPort: PouchInterface;
        port drainagePort;
        port ventPort: FilterInterface;
        
        action collectEffluent {
            in incomingEffluent: Effluent;
            in currentVol: EffluentVolume;
            in maxCap: EffluentVolume;
            out newVolume: EffluentVolume;
            out capacityPercentage: Real;
        }
        
        action checkCapacity {
            in volume: EffluentVolume;
            in capacity: EffluentVolume;
            out warningTriggered: Boolean;
        }
    }
    
    part def CharcoalFilter {
        attribute activated: Boolean;
        attribute efficiency: OdorReductionEfficiency;
        attribute saturationLevel: Real;
        attribute lifespan: WearDuration;
        
        port gasInlet: FilterInterface;
        port airOutlet;
        
        action neutralizeOdor {
            in odorousGas: OdorousGas;
            in filterEfficiency: OdorReductionEfficiency;
            out filteredAir: FilteredAir;
            out odorReduction: Real;
        }
        
        action monitorSaturation {
            in usageTime: WearDuration;
            in gasVolume: Real;
            out saturation: Real;
        }
    }
    
    part def LeakageDetectionSensor {
        attribute sensorActive: Boolean;
        attribute sensitivity: Real;
        
        action detectMoisture {
            in moistureLevel: Real;
            in adhesionStrength: AdhesionForce;
            out leakDetected: Boolean;
        }
        
        action monitorSealIntegrity {
            in barrierIntegrity: Real;
            in pouchIntegrity: Real;
            out sealStatus: Boolean;
        }
    }
    
    part def AlertModule {
        attribute alertActive: Boolean;
        attribute currentAlert: AlertType;
        attribute visualIndicator: Boolean;
        attribute audioEnabled: Boolean;
        
        action generateAlert {
            in alertCondition: Boolean;
            in alertType: AlertType;
            out alertActivated: Boolean;
            out notificationSent: Boolean;
        }
        
        action clearAlert {
            in userAcknowledgement: Boolean;
            out alertCleared: Boolean;
        }
    }
    
    part def ComfortLayer {
        attribute softMaterial: Boolean;
        attribute breathable: Boolean;
        attribute hypoallergenic: Boolean;
        
        action provideComfort {
            in wearDuration: WearDuration;
            out comfortLevel: Real;
        }
    }
    
    requirement def OstomyCareSystemRequirement {
        doc /* The ostomy care system shall safely and discreetly collect bodily effluent 
               from a stoma while protecting peristomal skin and maintaining patient dignity. */
        
        require containmentRequirement;
        require skinProtectionRequirement;
        require odorControlRequirement;
        require wearTimeRequirement;
        require leakPreventionRequirement;
    }
    
    requirement <'REQ-OST-001'> containmentRequirement {
        doc /* The system shall securely contain all effluent without leakage 
               for the duration of wear time. */
    }
    
    requirement <'REQ-OST-002'> skinProtectionRequirement {
        doc /* The skin barrier shall protect peristomal skin from effluent contact 
               and maintain healthy skin condition. */
    }
    
    requirement <'REQ-OST-003'> odorControlRequirement {
        doc /* The integrated filter shall reduce odor by at least 95% 
               to maintain discretion. */
    }
    
    requirement <'REQ-OST-004'> wearTimeRequirement {
        doc /* The system shall maintain integrity and adhesion for minimum 
               wear time of 48 hours under normal conditions. */
    }
    
    requirement <'REQ-OST-005'> leakPreventionRequirement {
        doc /* The system shall detect potential leakage conditions and alert 
               the user before leakage occurs. */
    }
    
    part def OstomySystem {
        attribute deviceID: DeviceID;
        attribute patientID: PatientID;
        attribute systemState: SystemState;
        attribute applicationTime: WearDuration;
        attribute totalWearTime: WearDuration;
        
        part skinBarrier: SkinBarrier;
        part collectionPouch: CollectionPouch;
        part charcoalFilter: CharcoalFilter;
        part leakageSensor: LeakageDetectionSensor;
        part alertModule: AlertModule;
        part comfortLayer: ComfortLayer;
        
        connection barrierToPouchConnection
            connect skinBarrier.pouchPort to collectionPouch.barrierPort;
        
        connection pouchToFilterConnection
            connect collectionPouch.ventPort to charcoalFilter.gasInlet;
        
        action manageOstomyCare {
            first start;
            then prepareApplication;
            
            action prepareApplication {
                doc /* Prepare skin and barrier for application */
            }
            then applyBarrier;
            
            action applyBarrier {
                action cleanSkin {
                    doc /* Clean and dry peristomal skin */
                }
                then action positionBarrier {
                    doc /* Center barrier over stoma */
                }
                then action pressToAdhere {
                    in skinCondition: SkinpH;
                    in currentWearTime: WearDuration;
                    out adhesionStatus: Real;
                }
            }
            then attachPouch;
            
            action attachPouch {
                doc /* Securely attach collection pouch to barrier */
            }
            then merge continuousOperation;
            
            action continuousOperation {
                action monitorCollection {
                    action receiveEffluent {
                        in incomingEffluent: Effluent;
                        in currentVol: EffluentVolume;
                        in maxCap: EffluentVolume;
                        out newVolume: EffluentVolume;
                        out capacityPercentage: Real;
                    }
                    
                    action filterGas {
                        in odorousGas: OdorousGas;
                        in filterEfficiency: OdorReductionEfficiency;
                        out filteredAir: FilteredAir;
                        out odorReduction: Real;
                    }
                    
                    action checkForLeaks {
                        in moistureLevel: Real;
                        in adhesionStrength: AdhesionForce;
                        out leakDetected: Boolean;
                    }
                    
                    action assessCapacity {
                        in volume: EffluentVolume;
                        in capacity: EffluentVolume;
                        out warningTriggered: Boolean;
                    }
                }
                
                then decide;
                    if monitorCollection.checkForLeaks.leakDetected == true then handleLeakage;
                    if monitorCollection.assessCapacity.warningTriggered == true then handleCapacityWarning;
                else continuousOperation;
            }
            
            action handleLeakage {
                action activateLeakAlert {
                    in alertCondition: Boolean;
                    in alertType: AlertType;
                    out alertActivated: Boolean;
                    out notificationSent: Boolean;
                }
            }
            then requireSystemChange;
            
            action handleCapacityWarning {
                action activateCapacityAlert {
                    in alertCondition: Boolean;
                    in alertType: AlertType;
                    out alertActivated: Boolean;
                    out notificationSent: Boolean;
                }
            }
            then emptyOrChangePouch;
            
            action handleWearTimeExpired {
                action activateWearTimeAlert {
                    in alertCondition: Boolean;
                    in alertType: AlertType;
                    out alertActivated: Boolean;
                    out notificationSent: Boolean;
                }
            }
            then requireSystemChange;
            
            action handleFilterSaturation {
                action activateFilterAlert {
                    in alertCondition: Boolean;
                    in alertType: AlertType;
                    out alertActivated: Boolean;
                    out notificationSent: Boolean;
                }
            }
            then requireSystemChange;
            
            action emptyOrChangePouch {
                doc /* Empty pouch through drainage port or replace with new pouch */
            }
            then continuousOperation;
            
            action requireSystemChange {
                doc /* Complete system change required - remove and replace barrier and pouch */
            }
            then done;
        }
        
        state systemStateMachine {
            entry; then unattached;
            
            state unattached;
            
            transition unattached_to_attached
                first unattached
                accept BarrierApplied
                then attached;
            
            state attached;
            
            transition attached_to_collecting
                first attached
                accept PouchAttached
                then collecting;
            
            state collecting;
            
            transition collecting_to_nearCapacity
                first collecting
                then nearCapacity;
            
            state nearCapacity;
            
            transition nearCapacity_to_collecting
                first nearCapacity
                accept PouchEmptied
                then collecting;
            
            transition nearCapacity_to_requiresChange
                first nearCapacity
                then requiresChange;
            
            transition collecting_to_compromised
                first collecting
                then compromised;
            
            state requiresChange;
            
            transition requiresChange_to_unattached
                first requiresChange
                accept SystemRemoved
                then unattached;
            
            state compromised;
            
            transition compromised_to_unattached
                first compromised
                accept SystemRemoved
                then unattached;
        }
    }
    
    part ostomySystem : OstomySystem {
        doc /* Convatec ostomy care system providing secure, discreet collection 
               of bodily effluent with integrated skin protection and odor control. */
        
        satisfy ostomyCareSystemRequirement;
    }
}
