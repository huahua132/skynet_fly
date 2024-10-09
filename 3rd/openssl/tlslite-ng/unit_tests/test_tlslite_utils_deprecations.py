# Copyright (c) 2018, Hubert Kario
#
# See the LICENSE file for legal information regarding use of this file.

# compatibility with Python 2.6, for that we need unittest2 package,
# which is not available on 3.3 or 3.4
try:
    import unittest2 as unittest
except ImportError:
    import unittest

try:
    import mock
    from mock import call
except ImportError:
    import unittest.mock as mock
    from unittest.mock import call

from tlslite.utils.deprecations import deprecated_params, \
        deprecated_attrs, deprecated_class_name, \
        deprecated_method

# see https://github.com/pytest-dev/py/issues/110
# preload the list until the list of loaded modules is static
try:
    import py.error
except ImportError:
    pass  # ignore
import sys
while True:
    end = True
    for v in list(sys.modules.values()):
        old = set(sys.modules.values())
        _ = getattr(v, '__warningregistry__', None)
        new = set(sys.modules.values())
        if new - old:
            end = False
    if end:
        break
for v in list(sys.modules.values()):
    old = set(sys.modules.values())
    _ = getattr(v, '__warningregistry__', None)
    new = set(sys.modules.values())
    if new - old:
        print("changed: {0}".format(new - old))


class TestDeprecatedClassName(unittest.TestCase):
    def test_check_class(self):
        @deprecated_class_name('bad_name')
        class Test1(object):
            def __init__(self, param):
                self.param = param

            def method(self):
                return self.param

        instance = Test1('value')
        self.assertEqual('value', instance.method())
        self.assertIsInstance(instance, bad_name)
        self.assertIsInstance(instance, Test1)

        with self.assertWarns(DeprecationWarning) as e:
            instance = bad_name('value')
        self.assertIn('Test1', str(e.warning))
        self.assertIn('bad_name', str(e.warning))

        with self.assertWarns(DeprecationWarning) as e:
            val = bad_name('value')
        self.assertIn('Test1', str(e.warning))
        self.assertIn('bad_name', str(e.warning))

    def test_check_callable(self):
        @deprecated_class_name('bad_func')
        def good_func(param):
            return "got '{0}'".format(param)

        self.assertEqual("got 'some'", good_func('some'))

        with self.assertWarns(DeprecationWarning) as e:
            val = bad_func('other')
        self.assertIn('good_func', str(e.warning))
        self.assertIn('bad_func', str(e.warning))
        self.assertEqual("got 'other'", val)

    def test_check_with_duplicated_name(self):
        @deprecated_class_name('bad_func2')
        def good_func():
            return None

        with self.assertRaises(NameError):
            @deprecated_class_name('bad_func2')
            def other_func():
                return None


class TestDeprecatedParams(unittest.TestCase):
    def test_no_changes(self):
        @deprecated_params({})
        def method(param_a, param_b):
            """Some doc string."""
            return (param_a, param_b)

        a = mock.Mock()
        b = mock.Mock()

        r = method(param_a=a, param_b=b)

        self.assertIsInstance(r, tuple)
        self.assertEqual(r, (a, b))
        self.assertIs(r[0], a)
        self.assertIs(r[1], b)

        self.assertEqual("Some doc string.", method.__doc__)

    def test_change_param(self):
        @deprecated_params({'param_a': 'old_param'})
        def method(param_a, param_b):
            return (param_a, param_b)

        old = mock.Mock()
        b = mock.Mock()

        with self.assertWarns(DeprecationWarning) as e:
            r = method(old_param=old, param_b=b)

        self.assertIsInstance(r, tuple)
        self.assertEqual(r, (old, b))
        self.assertIs(r[0], old)
        self.assertIs(r[1], b)

        self.assertIn('old_param', str(e.warning))

    def test_both_params(self):
        @deprecated_params({'param_a': 'older_param'})
        def method(param_a, param_b):
            return (param_a, param_b)

        a = mock.Mock()
        b = mock.Mock()
        c = mock.Mock()

        with self.assertRaises(TypeError) as e:
            method(param_a=a, param_b=b, older_param=c)

        self.assertIn('multiple values', str(e.exception))

    def test_in_class(self):
        class Clazz(object):
            @staticmethod
            @deprecated_params({"new_param": "old_param"})
            def method(param, new_param=None):
                return "{0} {1}".format(param, new_param)

        instance = Clazz()

        self.assertEqual(instance.method("aa", "BB"), "aa BB")

        with self.assertWarns(DeprecationWarning) as e:
            self.assertEqual(instance.method("aa", old_param="CC"), "aa CC")
        self.assertIn("old_param", str(e.warning))
        self.assertIn("new_param", str(e.warning))

        with self.assertWarns(DeprecationWarning) as e:
            self.assertEqual(Clazz.method("g", old_param="D"), "g D")
        self.assertIn("old_param", str(e.warning))
        self.assertIn("new_param", str(e.warning))

    def test_deprecated_twice(self):
        @deprecated_params({'param_a': 'paramA'})
        @deprecated_params({'param_b': 'ParamB'},
                           "{old_name} custom {new_name}")
        def method(param_a, param_b):
            return "{0} {1}".format(param_a, param_b)

        with self.assertWarns(DeprecationWarning) as e:
            self.assertEqual(method(paramA="aa", param_b="ZZ"), "aa ZZ")

        self.assertIn("paramA", str(e.warning))
        self.assertIn("param_a", str(e.warning))
        self.assertNotIn("custom", str(e.warning))

        with self.assertWarns(DeprecationWarning) as e:
            self.assertEqual(method("aa", ParamB="zz"), "aa zz")

        self.assertIn("ParamB", str(e.warning))
        self.assertIn("param_b", str(e.warning))
        self.assertIn("custom", str(e.warning))


class TestDeprecatedFields(unittest.TestCase):
    def test_no_change(self):

        @deprecated_attrs({})
        class Clazz(object):
            """Some nice class."""
            class_field = "I'm class_field"

            def __init__(self):
                self.new_field = "I'm new_field"

            def new_method(self):
                """Good method."""
                return "in new_method"

            @staticmethod
            def new_static_method():
                return "in new_static_method"

            @classmethod
            def new_cls_method(cls, param):
                return "cls methd: {0}".format(param)

        instance = Clazz()

        self.assertEqual(instance.new_field, "I'm new_field")
        self.assertEqual(instance.class_field, "I'm class_field")
        self.assertEqual(instance.new_method(), "in new_method")
        self.assertEqual(instance.new_static_method(), "in new_static_method")
        self.assertEqual(instance.new_cls_method("a"), "cls methd: a")
        self.assertEqual(Clazz.new_cls_method("a"), "cls methd: a")
        self.assertEqual(Clazz.new_static_method(), "in new_static_method")
        self.assertEqual(instance.__doc__, "Some nice class.")
        self.assertEqual(instance.new_method.__doc__, "Good method.")

    def test_deprecated_instance_variable(self):
        @deprecated_attrs({"new_field": "old_field"})
        class Clazz(object):
            def __init__(self):
                self.new_field = "I'm new_field"

        instance = Clazz()

        self.assertEqual(instance.new_field, "I'm new_field")

        with self.assertWarns(DeprecationWarning) as e:
            self.assertEqual(instance.old_field, "I'm new_field")
            instance.old_field = "I've been set"

        self.assertEqual(instance.new_field, "I've been set")

        self.assertIn("old_field", str(e.warning))

        with self.assertWarns(DeprecationWarning):
            del instance.old_field

        self.assertFalse(hasattr(instance, "new_field"))

    def test_deprecated_instance_method(self):
        @deprecated_attrs({"new_method": "old_method"})
        class Clazz(object):
            def new_method(self, param):
                return "new_method: {0}".format(param)

        instance = Clazz()

        self.assertEqual(instance.new_method("aa"), "new_method: aa")
        with self.assertWarns(DeprecationWarning) as e:
            self.assertEqual(instance.old_method("aa"), "new_method: aa")

        self.assertIn("old_method", str(e.warning))

    def test_deprecated_class_method(self):
        @deprecated_attrs({"foo": "bar"})
        class Clazz(object):
            @classmethod
            def foo(cls, arg):
                return "foo: {0}".format(arg)

        instance = Clazz()

        self.assertEqual(instance.foo("aa"), "foo: aa")
        self.assertEqual(Clazz.foo("aa"), "foo: aa")

        with self.assertWarns(DeprecationWarning) as e:
            self.assertEqual(instance.bar("aa"), "foo: aa")
        self.assertIn("bar", str(e.warning))

        with self.assertWarns(DeprecationWarning) as e:
            self.assertEqual(Clazz.bar("aa"), "foo: aa")
        self.assertIn("bar", str(e.warning))

        self.assertFalse(hasattr(Clazz, "non_existing"))

    def test_deprecated_static_method(self):
        @deprecated_attrs({"new_stic": "old_stic"})
        class Clazz(object):
            @staticmethod
            def new_stic(param):
                return "new_stic: {0}".format(param)

        instance = Clazz()

        self.assertEqual(instance.new_stic("aaa"), "new_stic: aaa")
        self.assertEqual(Clazz.new_stic("aaa"), "new_stic: aaa")
        with self.assertWarns(DeprecationWarning) as e:
            self.assertEqual(instance.old_stic("aaa"), "new_stic: aaa")
        self.assertIn("old_stic", str(e.warning))
        with self.assertWarns(DeprecationWarning) as e:
            self.assertEqual(Clazz.old_stic("aaa"), "new_stic: aaa")
        self.assertIn("old_stic", str(e.warning))

    def test_deprecated_class_variable(self):
        @deprecated_attrs({"new_cvar": "old_cvar"})
        class Clazz(object):
            new_cvar = "some string"

            def method(self):
                return self.new_cvar

        instance = Clazz()

        self.assertEqual(instance.method(), "some string")
        Clazz.new_cvar = bytearray(b"new string")
        self.assertEqual(instance.new_cvar, b"new string")

        with self.assertWarns(DeprecationWarning) as e:
            self.assertEqual(instance.old_cvar, b"new string")
        self.assertIn("old_cvar", str(e.warning))
        self.assertIn("new_cvar", str(e.warning))

        with self.assertWarns(DeprecationWarning) as e:
            self.assertEqual(Clazz.old_cvar, b"new string")
        self.assertIn("old_cvar", str(e.warning))
        self.assertIn("new_cvar", str(e.warning))

        # direct assignment to old value won't work, ex:
        # Clazz.old_cvar = b'newest string'
        with self.assertWarns(DeprecationWarning) as e:
            Clazz.old_cvar[:] = b"newest string"
        self.assertIn("old_cvar", str(e.warning))
        self.assertIn("new_cvar", str(e.warning))

        self.assertEqual(instance.method(), b"newest string")

    def test_class_with_custom_getattr(self):
        @deprecated_attrs({"new_cvar": "old_cvar"})
        class Clazz(object):
            new_cvar = "first title"

            def __getattr__(self, name):
                if name == "intresting":
                    return "some value"
                raise AttributeError("Clazz does not have {0}".format(name))

        instance = Clazz()

        self.assertEqual(instance.intresting, "some value")
        with self.assertWarns(DeprecationWarning) as e:
            self.assertEqual(instance.old_cvar, "first title")

        self.assertFalse(hasattr(instance, "non_existing"))

    def test_deprecated_attrs_variable_deletion(self):
        @deprecated_attrs({"new_cvar": "old_cvar"})
        class Clazz(object):
            new_cvar = "first title"

            def __init__(self):
                self.val = "something"

            @classmethod
            def method(cls):
                return cls.new_cvar

        instance = Clazz()

        self.assertEqual(instance.method(), "first title")
        self.assertEqual(instance.new_cvar, "first title")

        with self.assertWarns(DeprecationWarning) as e:
            self.assertEqual(Clazz.old_cvar, "first title")
        self.assertIn("old_cvar", str(e.warning))
        self.assertIn("new_cvar", str(e.warning))

        with self.assertWarns(DeprecationWarning) as e:
            self.assertEqual(instance.old_cvar, "first title")
        self.assertIn("old_cvar", str(e.warning))
        self.assertIn("new_cvar", str(e.warning))

        Clazz.new_cvar = "second"

        self.assertEqual(instance.method(), "second")
        with self.assertWarns(DeprecationWarning) as e:
            self.assertEqual(instance.old_cvar, "second")
        self.assertIn("old_cvar", str(e.warning))
        self.assertIn("new_cvar", str(e.warning))

        with self.assertWarns(DeprecationWarning) as e:
            Clazz.old_cvar = "third"
        self.assertIn("old_cvar", str(e.warning))
        self.assertIn("new_cvar", str(e.warning))

        self.assertEqual(instance.method(), "third")
        self.assertEqual(Clazz.new_cvar, "third")
        self.assertEqual(instance.new_cvar, "third")

        with self.assertWarns(DeprecationWarning) as e:
            del Clazz.old_cvar
        self.assertIn("old_cvar", str(e.warning))
        self.assertIn("new_cvar", str(e.warning))

        self.assertFalse(hasattr(Clazz, "new_cvar"))
        with self.assertWarns(DeprecationWarning) as e:
            self.assertFalse(hasattr(Clazz, "old_cvar"))

    def test_class_variable_deletion(self):
        @deprecated_attrs({"new_cvar": "old_cvar"})
        class Clazz(object):
            new_cvar = "first title"

            @classmethod
            def method(cls):
                return cls.new_cvar

        instance = Clazz()

        self.assertEqual(instance.method(), "first title")
        self.assertEqual(instance.new_cvar, "first title")

        with self.assertWarns(DeprecationWarning) as e:
            self.assertEqual(Clazz.old_cvar, "first title")
        self.assertIn("old_cvar", str(e.warning))
        self.assertIn("new_cvar", str(e.warning))

        with self.assertWarns(DeprecationWarning) as e:
            self.assertEqual(instance.old_cvar, "first title")
        self.assertIn("old_cvar", str(e.warning))
        self.assertIn("new_cvar", str(e.warning))

        Clazz.new_cvar = "second"

        self.assertEqual(instance.method(), "second")
        with self.assertWarns(DeprecationWarning) as e:
            self.assertEqual(instance.old_cvar, "second")
        self.assertIn("old_cvar", str(e.warning))
        self.assertIn("new_cvar", str(e.warning))

        with self.assertWarns(DeprecationWarning) as e:
            Clazz.old_cvar = "third"
        self.assertIn("old_cvar", str(e.warning))
        self.assertIn("new_cvar", str(e.warning))

        self.assertEqual(instance.method(), "third")
        self.assertEqual(Clazz.new_cvar, "third")
        self.assertEqual(instance.new_cvar, "third")

        with self.assertWarns(DeprecationWarning) as e:
            del Clazz.old_cvar
        self.assertIn("old_cvar", str(e.warning))
        self.assertIn("new_cvar", str(e.warning))

        self.assertFalse(hasattr(Clazz, "new_cvar"))
        with self.assertWarns(DeprecationWarning) as e:
            self.assertFalse(hasattr(Clazz, "old_cvar"))


class TestDeprecatedMethods(unittest.TestCase):
    def test_deprecated_method(self):

        @deprecated_method("Please use foo method instead.")
        def test(param):
            return param

        with self.assertWarns(DeprecationWarning) as e:
            r = test("test")
            self.assertEqual(r, "test")

        self.assertEqual("test is a deprecated method. Please" \
                         " use foo method instead.",
                         str(e.warning))
