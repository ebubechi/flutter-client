import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:invoiceninja_flutter/data/models/payment_term_model.dart';
import 'package:redux/redux.dart';
import 'package:invoiceninja_flutter/utils/platforms.dart';
import 'package:invoiceninja_flutter/redux/app/app_middleware.dart';
import 'package:invoiceninja_flutter/data/models/models.dart';
import 'package:invoiceninja_flutter/redux/ui/ui_actions.dart';
import 'package:invoiceninja_flutter/ui/payment_term/payment_term_screen.dart';
import 'package:invoiceninja_flutter/ui/payment_term/edit/payment_term_edit_vm.dart';
import 'package:invoiceninja_flutter/redux/payment_term/payment_term_actions.dart';
import 'package:invoiceninja_flutter/redux/app/app_state.dart';
import 'package:invoiceninja_flutter/data/repositories/payment_term_repository.dart';

List<Middleware<AppState>> createStorePaymentTermsMiddleware([
  PaymentTermRepository repository = const PaymentTermRepository(),
]) {
  final viewPaymentTermList = _viewPaymentTermList();
  final editPaymentTerm = _editPaymentTerm();
  final loadPaymentTerms = _loadPaymentTerms(repository);
  final loadPaymentTerm = _loadPaymentTerm(repository);
  final savePaymentTerm = _savePaymentTerm(repository);
  final archivePaymentTerm = _archivePaymentTerm(repository);
  final deletePaymentTerm = _deletePaymentTerm(repository);
  final restorePaymentTerm = _restorePaymentTerm(repository);

  return [
    TypedMiddleware<AppState, ViewPaymentTermList>(viewPaymentTermList),
    TypedMiddleware<AppState, EditPaymentTerm>(editPaymentTerm),
    TypedMiddleware<AppState, LoadPaymentTerms>(loadPaymentTerms),
    TypedMiddleware<AppState, LoadPaymentTerm>(loadPaymentTerm),
    TypedMiddleware<AppState, SavePaymentTermRequest>(savePaymentTerm),
    TypedMiddleware<AppState, ArchivePaymentTermsRequest>(archivePaymentTerm),
    TypedMiddleware<AppState, DeletePaymentTermsRequest>(deletePaymentTerm),
    TypedMiddleware<AppState, RestorePaymentTermsRequest>(restorePaymentTerm),
  ];
}

Middleware<AppState> _editPaymentTerm() {
  return (Store<AppState> store, dynamic dynamicAction, NextDispatcher next) {
    final action = dynamicAction as EditPaymentTerm;

    if (!action.force &&
        hasChanges(store: store, context: action.context, action: action)) {
      return;
    }

    next(action);

    store.dispatch(UpdateCurrentRoute(PaymentTermEditScreen.route));

    if (isMobile(action.context)) {
      action.navigator.pushNamed(PaymentTermEditScreen.route);
    }
  };
}

Middleware<AppState> _viewPaymentTermList() {
  return (Store<AppState> store, dynamic dynamicAction, NextDispatcher next) {
    final action = dynamicAction as ViewPaymentTermList;

    if (!action.force &&
        hasChanges(store: store, context: action.context, action: action)) {
      return;
    }

    next(action);

    if (store.state.paymentTermState.isStale) {
      store.dispatch(LoadPaymentTerms());
    }

    store.dispatch(UpdateCurrentRoute(PaymentTermScreen.route));

    if (isMobile(action.context)) {
      Navigator.of(action.context).pushNamedAndRemoveUntil(
          PaymentTermScreen.route, (Route<dynamic> route) => false);
    }
  };
}

Middleware<AppState> _archivePaymentTerm(PaymentTermRepository repository) {
  return (Store<AppState> store, dynamic dynamicAction, NextDispatcher next) {
    final action = dynamicAction as ArchivePaymentTermsRequest;
    final prevPaymentTerms = action.paymentTermIds
        .map((id) => store.state.paymentTermState.map[id])
        .toList();
    repository
        .bulkAction(store.state.credentials, action.paymentTermIds,
            EntityAction.archive)
        .then((List<PaymentTermEntity> paymentTerms) {
      store.dispatch(ArchivePaymentTermsSuccess(paymentTerms));
      if (action.completer != null) {
        action.completer.complete(null);
      }
    }).catchError((Object error) {
      print(error);
      store.dispatch(ArchivePaymentTermsFailure(prevPaymentTerms));
      if (action.completer != null) {
        action.completer.completeError(error);
      }
    });

    next(action);
  };
}

Middleware<AppState> _deletePaymentTerm(PaymentTermRepository repository) {
  return (Store<AppState> store, dynamic dynamicAction, NextDispatcher next) {
    final action = dynamicAction as DeletePaymentTermsRequest;
    final prevPaymentTerms = action.paymentTermIds
        .map((id) => store.state.paymentTermState.map[id])
        .toList();
    repository
        .bulkAction(
            store.state.credentials, action.paymentTermIds, EntityAction.delete)
        .then((List<PaymentTermEntity> paymentTerms) {
      store.dispatch(DeletePaymentTermsSuccess(paymentTerms));
      if (action.completer != null) {
        action.completer.complete(null);
      }
    }).catchError((Object error) {
      print(error);
      store.dispatch(DeletePaymentTermsFailure(prevPaymentTerms));
      if (action.completer != null) {
        action.completer.completeError(error);
      }
    });

    next(action);
  };
}

Middleware<AppState> _restorePaymentTerm(PaymentTermRepository repository) {
  return (Store<AppState> store, dynamic dynamicAction, NextDispatcher next) {
    final action = dynamicAction as RestorePaymentTermsRequest;
    final prevPaymentTerms = action.paymentTermIds
        .map((id) => store.state.paymentTermState.map[id])
        .toList();
    repository
        .bulkAction(store.state.credentials, action.paymentTermIds,
            EntityAction.restore)
        .then((List<PaymentTermEntity> paymentTerms) {
      store.dispatch(RestorePaymentTermsSuccess(paymentTerms));
      if (action.completer != null) {
        action.completer.complete(null);
      }
    }).catchError((Object error) {
      print(error);
      store.dispatch(RestorePaymentTermsFailure(prevPaymentTerms));
      if (action.completer != null) {
        action.completer.completeError(error);
      }
    });

    next(action);
  };
}

Middleware<AppState> _savePaymentTerm(PaymentTermRepository repository) {
  return (Store<AppState> store, dynamic dynamicAction, NextDispatcher next) {
    final action = dynamicAction as SavePaymentTermRequest;
    repository
        .saveData(store.state.credentials, action.paymentTerm)
        .then((PaymentTermEntity paymentTerm) {
      if (action.paymentTerm.isNew) {
        store.dispatch(AddPaymentTermSuccess(paymentTerm));
      } else {
        store.dispatch(SavePaymentTermSuccess(paymentTerm));
      }

      action.completer.complete(paymentTerm);

      final paymentTermUIState = store.state.paymentTermUIState;
      if (paymentTermUIState.saveCompleter != null) {
        paymentTermUIState.saveCompleter.complete(paymentTerm);
      }
    }).catchError((Object error) {
      print(error);
      store.dispatch(SavePaymentTermFailure(error));
      action.completer.completeError(error);
    });

    next(action);
  };
}

Middleware<AppState> _loadPaymentTerm(PaymentTermRepository repository) {
  return (Store<AppState> store, dynamic dynamicAction, NextDispatcher next) {
    final action = dynamicAction as LoadPaymentTerm;
    final AppState state = store.state;

    if (state.isLoading) {
      next(action);
      return;
    }

    store.dispatch(LoadPaymentTermRequest());
    repository
        .loadItem(state.credentials, action.paymentTermId)
        .then((paymentTerm) {
      store.dispatch(LoadPaymentTermSuccess(paymentTerm));

      if (action.completer != null) {
        action.completer.complete(null);
      }
    }).catchError((Object error) {
      print(error);
      store.dispatch(LoadPaymentTermFailure(error));
      if (action.completer != null) {
        action.completer.completeError(error);
      }
    });

    next(action);
  };
}

Middleware<AppState> _loadPaymentTerms(PaymentTermRepository repository) {
  return (Store<AppState> store, dynamic dynamicAction, NextDispatcher next) {
    final action = dynamicAction as LoadPaymentTerms;
    final AppState state = store.state;

    if (!state.paymentTermState.isStale && !action.force) {
      next(action);
      return;
    }

    if (state.isLoading) {
      next(action);
      return;
    }

    final int updatedAt = (state.paymentTermState.lastUpdated / 1000).round();

    store.dispatch(LoadPaymentTermsRequest());
    repository.loadList(state.credentials, updatedAt).then((data) {
      store.dispatch(LoadPaymentTermsSuccess(data));

      if (action.completer != null) {
        action.completer.complete(null);
      }
      /*
      if (state.productState.isStale) {
        store.dispatch(LoadProducts());
      }
      */
    }).catchError((Object error) {
      print(error);
      store.dispatch(LoadPaymentTermsFailure(error));
      if (action.completer != null) {
        action.completer.completeError(error);
      }
    });

    next(action);
  };
}
