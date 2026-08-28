package NeedlelessConnectorSystem {
    import ScalarValues::*;
    import ISQ::*;
    
    // ---- Value Types with Units ----
    attribute def Force :> Real { unit 'N'; }
    attribute def Volume :> Real { unit 'mL'; }
    attribute def FlowRate :> Real { unit 'mL/min'; }
    attribute def Pressure :> Real { unit 'kPa'; }
    attribute def Length :> Real { unit 'mm'; }
    attribute def Diameter :> Real {> Real { unit 'mm'; }
    attribute def Duration :> Real { unit 's'; }
    attribute def MicrobialLoad :> Real { unit 'CFU'; }
    
    // ---- Item Types ----
    item def Medication {
        attribute concentration : Real;
        attribute volume : Volume;
    }
    
    item def SterileFluid :> Medication {
        attribute sterilityAssured : Boolean;
    }
    
    // ---- Port Definitions ----
    port def FluidPort {
        attribute flowDirection : String;
        attribute maxPressure : Pressure;
        out item med : SterileFluid;
        in item returnFlow : SterileFluid;
    }
    
    port def ProximalPort :> FluidPort {
        attribute connectorType : String = "Luer-Lock";
        attribute engagementForce : Force = 5.0;
    }
    
    port def DistalPort :> FluidPort {
        attribute connectorType : String = "IV-Lock";
        attribute maxPressure : Pressure = 300.0;
    }
    
    port def ActivationPort {
        attribute appliedForce : Force;
        attribute engaged : Boolean;
    }
    
    // ---- Requirements ----
    requirement def SafetyRequirement {
        doc /* Prevent needlestick injuries and maintain sterile closed pathway. */
        attribute id : String = "REQ-001";
    }
    
    requirement def SterilityRequirement {
        doc /* The connector must maintain a sterile, closed pathway to protect the patient from infection. */
        attribute id : String = "REQ-002";
        attribute maxMicrobialLoad : MicrobialLoad = 0;
    }
    
    requirement def AutoSealRequirement {
        doc /* Upon disconnection, the internal valve must automatically close and seal, preventing leakage. */
        attribute id : String = "REQ-003";
        attribute sealTime : Duration = 0.5;
    }
    
    requirement def ActivationForceRequirement {
        doc /* A specific force is required to engage the activation mechanism and open the valve. */
        attribute id : String = "REQ-004";
        attribute minEngagementForce : Force = 3.0;
        attribute maxEngagementForce : Force = 8.0;
    }
    
    requirement def FluidDeliveryRequirement {
        doc /* The system must transfer a specific volume of fluid from reservoir to patient. */
        attribute id : String = "REQ-005";
        attribute targetVolume : Volume = 50.0;
        attribute maxFlowRate : FlowRate = 20.0;
    }
    
    // ---- Part Definitions ----
    part def MechanicalValve {
        attribute sealDiameter : Diameter = 4.0;
        attribute springConstant : Real = 2.5;
        attribute openThreshold : Force = 3.0;
        attribute currentForce : Force;
        attribute isOpen : Boolean = false;
        
        port def ValveControlPort {
            in attribute appliedForce : Force;
            out attribute valveOpen : Boolean;
        }
        
        port controlPort : ValveControlPort;
        
        action def OpenValve {
            in force : Force;
            out opened : Boolean;
        }
        
        action def CloseValve {
            out sealed : Boolean;
        }
        
        state def ValveStates {
            entry; then Closed;
            state Closed;
            transition from Closed to Open
                when controlPort.appliedForce > openThreshold;
            state Open;
            transition from Open to Closed
                when controlPort.appliedForce <= openThreshold;
        }
        
        state machine valveStateMachine : ValveStates;
    }
    
    part def ActivationMechanism {
        attribute engagementForce : Force = 5.0;
        attribute travelDistance : Length = 3.0;
        attribute isEngaged : Boolean = false;
        
        port def ActivationInputPort {
            in attribute appliedForce : Force;
            out attribute engaged : Boolean;
            out attribute outputForce : Force;
        }
        
        port inputPort : ActivationInputPort;
        
        action def Engage {
            in force : Force;
            out engaged : Boolean;
            out transmittedForce : Force;
        }
        
        action def Disengage {
            out disengaged : Boolean;
        }
    }
    
    part def AntimicrobialBarrier {
        attribute coatingType : String = "Chlorhexidine";
        attribute coverageArea : Real = 1.2;
        attribute efficacyPercent : Real = 99.9;
        attribute remainingLife : Integer = 100;
        
        action def Disinfect {
            in surfaceArea : Real;
            out microbialReduction : MicrobialLoad;
        }
    }
    
    part def SyringeAdapter {
        attribute adapterType : String = "Luer-Lock";
        attribute luerDiameter : Diameter = 4.0;
        attribute lockThreads : Integer = 2;
        attribute appliedForce : Force;
        attribute isAttached : Boolean = false;
        
        port def AdapterPort {
            out attribute engagementForce : Force;
            out attribute attached : Boolean;
        }
        
        port adapterPort : AdapterPort;
        
        action def Attach {
            in targetForce : Force;
            out attached : Boolean;
        }
        
        action def Detach {
            out detached : Boolean;
        }
    }
    
    part def FluidReservoir {
        attribute reservoirType : String = "IV-Bag";
        attribute capacity : Volume = 250.0;
        attribute currentVolume : Volume;
        attribute fluidType : SterileFluid;
        
        port def ReservoirPort {
            out item fluid : SterileFluid;
            out attribute availableVolume : Volume;
        }
        
        port reservoirPort : ReservoirPort;
        
        action def Dispense {
            in requestedVolume : Volume;
            out dispensedFluid : SterileFluid;
        }
    }
    
    part def IVLine {
        attribute lineLength : Length = 1500.0;
        attribute innerDiameter : Diameter = 2.5;
        attribute flowResistance : Real = 0.8;
        attribute isPatent : Boolean = true;
        
        port def IVLinePort {
            in item incomingFluid : SterileFluid;
            out attribute flowConfirmed : Boolean;
        }
        
        port linePort : IVLinePort;
        
        action def DeliverFluid {
            in fluid : SterileFluid;
            out delivered : Boolean;
        }
    }
    
    part def Patient {
        attribute patientID : String;
        attribute vascularAccessSite : String = "Left-Antecubital";
        
        port def PatientPort {
            in item medication : SterileFluid;
            out attribute received : Boolean;
        }
        
        port patientPort : PatientPort;
        
        action def ReceiveMedication {
            in med : SterileFluid;
            out received : Boolean;
        }
    }
    
    // ---- Central Component: Needleless Connector ----
    part def NeedlelessConnector {
        attribute connectorID : String;
        attribute bodyMaterial : String = "Polycarbonate";
        attribute bodyLength : Length = 35.0;
        attribute bodyDiameter : Diameter = 10.0;
        attribute isSterile : Boolean = true;
        attribute maxOperatingPressure : Pressure = 250.0;
        
        // Ports
        port proximalPort : ProximalPort;
        port distalPort : DistalPort;
        
        // Internal parts
        part mechanicalValve : MechanicalValve;
        part activationMechanism : ActivationMechanism;
        part antimicrobialBarrier : AntimicrobialBarrier;
        part internalChannel {
            attribute channelDiameter : Diameter = 3.0;
            attribute channelLength : Length = 30.0;
            attribute isSealed : Boolean = true;
        }
        
        // Connections between internal parts
        connection activationToValve
            connect activationMechanism.inputPort to mechanicalValve.controlPort;
        
        // State machine for connector operation
        state def ConnectorOperation {
            entry; then Disconnected;
            
            state Disconnected {
                doc /* Valve is closed and sealed; connector is sterile and ready. */
                entry action { 
                    mechanicalValve.isOpen = false; 
                    internalChannel.isSealed = true; 
                }
            }
            
            transition from Disconnected to Engaging
                when proximalPort.appliedForce > activationMechanism.engagementForce;
            
            state Engaging {
                doc /* Syringe adapter is being attached; activation mechanism engages. */
                entry action {
                    activationMechanism.isEngaged = true;
                    antimicrobialBarrier.remainingLife = antimicrobialBarrier.remainingLife - 1;
                }
                do action {
                    activationMechanism.inputPort.appliedForce = proximalPort.appliedForce;
                }
            }
            
            transition from Engaging to Connected
                when activationMechanism.inputPort.engaged == true;
            
            state Connected {
                doc /* Valve is open; fluid flows from proximal to distal port. */
                entry action {
                    mechanicalValve.isOpen = true;
                    internalChannel.isSealed = false;
                }
                do action {
                    distalPort.med = proximalPort.med;
                }
            }
            
            transition from Connected to Disengaging
                when proximalPort.appliedForce < 1.0;
            
            state Disengaging {
                doc /* Syringe adapter is being removed; valve begins to close. */
                entry action {
                    activationMechanism.isEngaged = false;
                }
            }
            
            transition from Disengaging to Sealing
                when activationMechanism.isEngaged == false;
            
            state Sealing {
                doc /* Valve automatically closes and seals; prevents leakage. */
                entry action {
                    mechanicalValve.isOpen = false;
                    internalChannel.isSealed = true;
                }
            }
            
            transition from Sealing to Disconnected
                when internalChannel.isSealed == true;
        }
        
        state machine connectorStateMachine : ConnectorOperation;
        
        // Administration action
        action def AdministerMedication {
            in reservoirFluid : SterileFluid;
            in targetVolume : Volume;
            out deliveredVolume : Volume;
            
            action attachSyringe {
                out attached : Boolean;
            }
            action openValve {
                in force : Force;
                out opened : Boolean;
            }
            action transferFluid {
                in volume : Volume;
                out transferred : SterileFluid;
            }
            action disconnectSyringe {
                out sealed : Boolean;
            }
            
            flow from attachSyringe.attached to openValve;
            flow from openValve.opened to transferFluid;
            flow from transferFluid.transferred to disconnectSyringe;
        }
    }
    
    // ---- System Assembly ----
    part def NeedlelessConnectorSystem {
        attribute systemID : String = "NCS-001";
        attribute systemActive : Boolean = false;
        
        // Requirements satisfaction
        satisfy SafetyRequirement;
        satisfy SterilityRequirement;
        satisfy AutoSealRequirement;
        satisfy ActivationForceRequirement;
        satisfy FluidDeliveryRequirement;
        
        // System parts
        part fluidReservoir : FluidReservoir {
            attribute currentVolume : Volume = 200.0;
        }
        
        part needlelessConnector : NeedlelessConnector {
            attribute connectorID : String = "NC-2025-001";
        }
        
        part ivLine : IVLine {
            attribute isPatent : Boolean = true;
        }
        
        part patient : Patient {
            attribute patientID : String = "P-7842";
        }
        
        part syringeAdapter : SyringeAdapter {
            attribute adapterType : String = "Luer-Lock";
        }
        
        // System connections
        connection reservoirToConnector
            connect fluidReservoir.reservoirPort to needlelessConnector.proximalPort;
        
        connection connectorToIVLine
            connect needlelessConnector.distalPort to ivLine.linePort;
        
        connection ivLineToPatient
            connect ivLine.linePort to patient.patientPort;
        
        // System-level administration behavior
        action def SystemAdministration {
            in medicationVolume : Volume = 50.0;
            out administrationComplete : Boolean;
            
            action prepareReservoir {
                out fluidReady : SterileFluid;
            }
            action connectAdapter {
                in adapter : SyringeAdapter;
                out connected : Boolean;
            }
            action activateConnector {
                in force : Force = 5.0;
                out valveOpen : Boolean;
            }
            action transferMedication {
                in volume : Volume;
                in fluid : SterileFluid;
                out delivered : SterileFluid;
            }
            action disconnectAndSeal {
                out sealed : Boolean;
            }
            action confirmDelivery {
                in fluid : SterileFluid;
                out confirmed : Boolean;
            }
            
            flow from prepareReservoir.fluidReady to transferMedication.fluid;
            flow from connectAdapter.connected to activateConnector;
            flow from activateConnector.valveOpen to transferMedication;
            flow from transferMedication.delivered to disconnectAndSeal;
            flow from transferMedication.delivered to confirmDelivery.fluid;
        }
        
        action administer : SystemAdministration;
    }
}
