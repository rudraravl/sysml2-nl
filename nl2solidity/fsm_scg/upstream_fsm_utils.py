# Verbatim copy from FSM-SCG (Luo et al., IJCAI 2025, arXiv:2505.08542; bib key luo2025fsm).
#   Repo:   https://github.com/pluto-ms/FSM-Smart-Contract-Generation
#   Commit: 9dcd83ed533cc12b6c6b91bdfa0bfc4c3a46c6ea (2025-02-06)
# The upstream repo has NO LICENSE file. NOT FOR REDISTRIBUTION: exclude this file from any
# public code release unless the authors grant permission.
# Do not edit the copied text below; deviations belong in run_fsm_scg.py and DEVIATIONS.md.
#
# Sources, each block unchanged apart from being gathered into one module:
#   utils/fsm_utils.py                  entire file
#   utils/data_utils.py                 extract_fsm, extract_code (as class data_utils)
#   evaluate/security/slither_check.py  merge_check_items, and the impact/confidence maps from compute_risk_score


# ---- utils/fsm_utils.py ----
import networkx as nx

class fsm_utils:

    @staticmethod
    def validate_fsm(fsm_data):
        states = {state["name"] for state in fsm_data["states"]}
        initial_state = fsm_data["initialState"]

        # Check if the initial state exists
        if initial_state not in states:
            return False, f"Initial state {initial_state} does not exist in the state list."

        # Check if all transition targets are valid
        for state in fsm_data["states"]:
            for transition in state.get("transitions", []):
                target = transition["target"]
                if target not in states:
                    return False, f"The target {target} of state {state['name']} is invalid."

        # Check if all triggers are defined in the event list
        valid_triggers = set(fsm_data.get("events", []))
        for state in fsm_data["states"]:
            for transition in state.get("transitions", []):
                trigger = transition["trigger"]
                if trigger not in valid_triggers:
                    return False, f"The trigger {trigger} of state {state['name']} is not defined in the event list."

        return True, "FSM validation passed"



    @staticmethod
    def check_reachability_and_cycles(fsm_data):
        G = nx.DiGraph()
        initial_state = fsm_data["initialState"]
        
        # Add states and transitions to the graph
        for state in fsm_data["states"]:
            for transition in state["transitions"]:
                G.add_edge(state["name"], transition["target"])
        
        # Check if all states are reachable from the initial state
        reachable_nodes = nx.descendants(G, initial_state) | {initial_state}
        all_states = {state["name"] for state in fsm_data["states"]}
        unreachable_states = all_states - reachable_nodes
        
        # Check for cycles in the graph
        has_cycle = nx.is_directed_acyclic_graph(G) == False
        
        return unreachable_states, has_cycle



# ---- utils/data_utils.py (excerpt) ----
import re


class data_utils:
    # Extracting Finite State Machines from Text
    @staticmethod
    def extract_fsm(mix_text):
        if re.match(r'^```(StateMachine/json)?', mix_text) and re.search(r'```$', mix_text):
            cleaned_json = re.sub(r'^```(StateMachine/json)?\s*|```$', '', mix_text, flags=re.MULTILINE)
        else:
            cleaned_json = mix_text  # If there is no label, return as is
        return cleaned_json
    

    # Extract code from text
    @staticmethod
    def extract_code(code):

        pattern = r'```solidity(.*?)```'

        match = re.search(pattern, code, re.DOTALL)
        
        if match:
            return match.group(1) 
        else:
            return code 
    


# ---- evaluate/security/slither_check.py (excerpt) ----
# Merge check items of the same type
def merge_check_items(check_items):
    # Group by check type
    check_items_grouped = {}
    for item in check_items:
        check_type = item['check_type']
        if check_type not in check_items_grouped:
            check_items_grouped[check_type] = []
        check_items_grouped[check_type].append(item)
    
    # Merge ranges within each check type
    merged_results = []
    for check_type, items in check_items_grouped.items():
        # Sort by starting line
        items = sorted(items, key=lambda x: (x['start_line'], x['end_line']))
        # Merge ranges
        merged = []
        current = items[0]
        for next_item in items[1:]:
            if next_item['start_line'] <= current['end_line']:  # 范围重叠或相邻
                current['end_line'] = max(current['end_line'], next_item['end_line'])
            else:
                merged.append(current)
                current = next_item
        merged.append(current)  # Add the last one
        # Add to final results
        merged_results.extend(merged)
    
    return merged_results


# From compute_risk_score:
impact_map = {'High': 3, 'Medium': 2, 'Low': 1}
confidence_map = {'High': 3, 'Medium': 2, 'Low': 1}
