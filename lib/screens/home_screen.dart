import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/expense.dart';
import '../services/expense_service.dart';
import '../services/export_service.dart';
import '../widgets/expense_tile.dart';
import 'add_expense_screen.dart';
import 'edit_expense_screen.dart';
 
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}
 
class _HomeScreenState extends State<HomeScreen> {
  ExpenseCategory? _selectedCategory;
  bool _hasShownBudgetAlert = false;
 
  String _label(ExpenseCategory? cat) {
    if (cat == null) return 'All';
    switch (cat) {
      case ExpenseCategory.food:          return 'Food';
      case ExpenseCategory.transport:     return 'Transport';
      case ExpenseCategory.shopping:      return 'Shopping';
      case ExpenseCategory.utilities:     return 'Utilities';
      case ExpenseCategory.entertainment: return 'Entertainment';
      case ExpenseCategory.other:         return 'Other';
    }
  }
 
  void _showBudgetDialog() {
    final settingsBox = Hive.box('settings');
    final currentBudget = settingsBox.get('monthly_budget', defaultValue: 0.0) as double;
    final budgetController = TextEditingController(text: currentBudget.toStringAsFixed(0));
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Set Monthly Budget'),
        content: TextField(
          controller: budgetController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Budget Amount (₱)',
            prefixText: '₱',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final budget = double.tryParse(budgetController.text.trim());
              if (budget != null && budget > 0) {
                await settingsBox.put('monthly_budget', budget);
                Navigator.pop(ctx);
                setState(() {});
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
 
  Future<void> _exportData() async {
    try {
      final filePath = await ExportService.exportCurrentMonth();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Exported to: $filePath'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
 
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SpendWise', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.attach_money),
            onPressed: _showBudgetDialog,
            tooltip: 'Set Monthly Budget',
          ),
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            onPressed: _exportData,
            tooltip: 'Export Monthly Report',
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => showAboutDialog(
              context: context,
              applicationName: 'SpendWise',
              applicationVersion: '1.0.0',
              children: [const Text('A personal expense tracker built with Hive.')],
            ),
          ),
        ],
      ),
      body: ValueListenableBuilder<Box<Expense>>(
        valueListenable: ExpenseService.listenable,
        builder: (context, box, _) {
          final double total = box.values.fold(0.0, (s, e) => s + e.amount);
          final List<Expense> expenses = _selectedCategory == null
              ? ExpenseService.getAllExpenses()
              : ExpenseService.getExpensesByCategory(_selectedCategory!);
 
          expenses.sort((a, b) => b.date.compareTo(a.date));
 
          return Column(
            children: [
              _buildSummaryCard(total, box.length),
              _buildFilterChips(),
              Expanded(child: _buildExpenseList(expenses)),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context, MaterialPageRoute(builder: (_) => const AddExpenseScreen())),
        icon: const Icon(Icons.add),
        label: const Text('Add Expense'),
      ),
    );
  }
 
  Widget _buildSummaryCard(double total, int count) {
    final settingsBox = Hive.box('settings');
    final budget = settingsBox.get('monthly_budget', defaultValue: 0.0) as double;
    final percentage = budget > 0 ? (total / budget).clamp(0.0, 1.0) : 0.0;
    
    if (percentage >= 0.8 && budget > 0 && !_hasShownBudgetAlert) {
      _hasShownBudgetAlert = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '⚠️ Budget Alert: You\'ve used ${(percentage * 100).toStringAsFixed(0)}% of your monthly budget!',
            ),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 4),
          ),
        );
      });
    }
    
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      elevation: 4,
      color: Theme.of(context).colorScheme.primaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Total Spending',
                    style: const TextStyle(fontSize: 14, color: Colors.black54)),
                  Text('$count expense${count == 1 ? '' : 's'}',
                    style: const TextStyle(fontSize: 12, color: Colors.black45)),
                ]),
                Text(
                  '₱${total.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold,
                    color: Colors.indigo),
                ),
              ],
            ),
            if (budget > 0) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Budget: ₱${budget.toStringAsFixed(0)}',
                      style: const TextStyle(fontSize: 12, color: Colors.black54)),
                  Text('${(percentage * 100).toStringAsFixed(0)}% used',
                      style: TextStyle(fontSize: 12, 
                          color: percentage >= 0.8 ? Colors.red : Colors.black54)),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: percentage,
                backgroundColor: Colors.grey[200],
                color: percentage >= 0.8 ? Colors.red : Colors.indigo,
                minHeight: 12,
                borderRadius: BorderRadius.circular(6),
              ),
            ],
          ],
        ),
      ),
    );
  }
 
  Widget _buildFilterChips() {
    final categories = [null, ...ExpenseCategory.values];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: categories.map((cat) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: FilterChip(
            label: Text(_label(cat)),
            selected: _selectedCategory == cat,
            onSelected: (_) => setState(() => _selectedCategory = cat),
          ),
        )).toList(),
      ),
    );
  }
 
  Widget _buildExpenseList(List<Expense> expenses) {
    if (expenses.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text('No expenses yet!',
            style: TextStyle(fontSize: 18, color: Colors.grey[600])),
          const SizedBox(height: 8),
          Text('Tap the button below to add your first expense.',
            style: TextStyle(color: Colors.grey[400])),
        ]),
      );
    }
    return ListView.builder(
      itemCount: expenses.length,
      itemBuilder: (ctx, i) {
        final expense = expenses[i];
        final int key = expense.key as int;
        return ExpenseTile(
          expense: expense,
          onDelete: () => ExpenseService.deleteExpense(key),
          onEdit: () => Navigator.push(ctx,
            MaterialPageRoute(builder: (_) =>
              EditExpenseScreen(expense: expense, expenseKey: key))),
        );
      },
    );
  }
}