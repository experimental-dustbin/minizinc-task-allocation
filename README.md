# Introduction
This is a small tutorial on [MiniZinc](https://www.minizinc.org) using a toy task allocation problem.

To follow along you'll need the MiniZinc IDE which can be downloaded from [minizinc.org](https://www.minizinc.org).

# Initial Parameters
The problem is about assigning a set of tasks to a set of hosts by minimizing some metric like cost. Each task has some requirements like how much memory and CPU it needs and the hosts similarly have properties like total memory, CPU, cost, etc.

I'm going to assume we have 10 host types but that's just for demonstration. In a production setting you'd have as many host types as necessary.

```
int: hostTypes = 10;
array[1..hostTypes] of int: hostCpu = [
  1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
array[1..hostTypes] of int: hostMem = [
  1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
array[1..hostTypes] of int: hostCost = [
  2, 4, 6, 8, 10, 12, 14, 16, 18, 20];
```

In the above we have 3 arrays indexed by host type IDs and each array expresses some property of the host type. In the example the host type that corresponds to ID `1` has the following properties: `hostCpu[1] = 1`, `hostMem[1] = 1`, `hostCost[1] = 2`. The units are arbitrary but they're supposed to correspond to some common unit like gigabytes for memory, core counts for CPU, and dollars/cents for cost.

Next we'll spell out the details of the tasks using the same pattern of assigning integer IDs to each task and then using arrays indexed by those IDs to express properties associated with the task.

```
int: numTasks = 10;
array[1..numTasks] of int: taskCpu = [
  1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
array[1..numTasks] of int: taskMem = [
  1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
```

Pretty simple, the tasks have memory and CPU requirements but like the hosts could have any number of other properties associated with them expressed in some common unit that can be compared with the host's properties.

If the units are not common then unit conversions are required when expressing constraints so it's easier to express things in units that are common to both the task and the host to simplify the constraints.

# Constraints
Now that we have the tasks and host descriptions we can specify a mapping from tasks to host types.

```
array[1..numTasks] of var 0..hostTypes: taskHostAssignment;
array[1..hostTypes] of var set of 1..numTasks: hostTaskAssignment;
```

The above arrays express two mappings: `task -> host type`, `host type -> { tasks }`. The two arrays are "inverses" of each other and we can express that by using one of MiniZinc's global constraints.

```
include "int_set_channel.mzn";
constraint int_set_channel(taskHostAssignment, hostTaskAssignment);
```

The above says that for every task `t` and host type `h` we have the following relationship: If `taskHostAssignment[t] = h` then `t in hostTaskAssignment[h]`. So to make it concrete, if tasks `1`, `2`, `3` are assigned to host type `10` then `hostTaskAssignment[10] = {1, 2, 3}`. The reason we set up this mapping is because it will allow us to express various constraints by iteration over `hostTaskAssignment`.

One such constraint is making sure the tasks can actually "fit" on a given host type. That means that each task can't have memory and CPU requirements that are larger than the host's limits.

```
constraint forall(h in 1..hostTypes)(
  forall(t in hostTaskAssignment[h])(
    taskCpu[t] <= hostCpu[h] /\
      taskMem[t] <= hostMem[h]
  )
);
```

In plain english, the above says the following: for every host `h` and for every task in `hostTaskAssignment[h]` it must be the case that the task's memory and CPU requirements are smaller than the host's limits (`taskCpu[t] <= hostCpu[h]` and `taskMem[t] <= hostMem[h]`). This is why using a common unit for both host types and tasks is important, otherwise the comparison is incorrect, i.e. we can't compare gigabytes with megabytes without some extra unit conversions.

Now that we have tasks assigned to host types we can figure out how many hosts of each type we'll need.

```
array[1..hostTypes] of var int: requiredHostCounts;
constraint forall(h in 1..hostTypes)(
  let {
    var int: perHostCpuTotal = sum(
      t in hostTaskAssignment[h])(taskCpu[t]);
    var int: perHostMemTotal = sum(
      t in hostTaskAssignment[h])(taskMem[t]);
    var int: cpuRemainder =
      if perHostCpuTotal mod hostCpu[h] > 0
      then 1 else 0 endif;
    var int memRemainder =
      if perHostMemTotal div hostMem[h] > 0
      then 1 else 0 endif;
  } in
  requiredHostCounts[h] = max(
    perHostCpuTotal div hostCpu[h] +
      cpuRemainder,
    perHostMemTotal div hostMem[h] +
      memRemainder)
);
```

That looks a little complicated but it's not. We just figure out what is the resource that is the limiting factor (memory or CPU) and then figure out how many hosts of that type we will need to overcome the limitation. So if the host had 2 units of memory and 1 unit of CPU and we had two tasks that each required 1 unit of CPU then the limiting factor would be CPU and we'd need 2 hosts of that type to run those tasks. But if the host had 2 units of CPU then both tasks could be co-located on a single host (assuming memory was not a limiting factor). That's what the division and remainder calculations are doing. We figure out the totals for each requirement and then figure out how many hosts are required to overcome the main limiting factor.

And with all of that set up we can calculate the total cost and ask MiniZinc to minimize it.

```
array[1..hostTypes] of var int: requiredHostCosts;
constraint forall(h in 1..hostTypes)(
  requiredHostCosts[h] =
    requiredHostCounts[h] * hostCost[h]
);
var int: totalCost = sum(h in 1..hostTypes)(
  requiredHostCosts[h]);
solve minimize totalCost;
```
To see the answer we'll need to output the relevant arrays.

```
output ["Cost: \(totalCost).\n"] ++
  ["Assignments: \(taskHostAssignment).\n"] ++
  ["Counts: \(requiredHostCounts)."];
```

And here's an example output

```
Cost: 114.
Assignments: [10, 9, 10, 10, 10, 10, 9, 9, 9, 10].
Counts: [0, 0, 0, 0, 0, 0, 0, 0, 3, 3].
```

According to that we need 6 hosts, 3 of which are of type ID `9`
and 3 of which are of type ID `10` with overall cost of 114 units. With the above composition of hosts we then map tasks `1`, `3`, `4`, `5`, `6`, and `10` to hosts of type ID `10` and the other tasks to hosts of type ID `9`.

# Further Reading
If you got this far then you'll probably enjoy learning more about [MiniZinc](https://www.minizinc.org). The [handbook](https://www.minizinc.org/doc-2.4.2/en/index.html) is a pretty good starting place.